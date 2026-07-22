#import "TimberVoxExecuTorchBridge.h"

#import <ExecuTorch/ExecuTorch.h>

namespace {

ExecuTorchTensor *FloatTensor(NSData *data, NSArray<NSNumber *> *shape) {
  return [[ExecuTorchTensor alloc]
      initWithBytesNoCopy:const_cast<void *>(data.bytes)
                    shape:shape
                  strides:@[]
           dimensionOrder:@[]
                 dataType:ExecuTorchDataTypeFloat
            shapeDynamism:ExecuTorchShapeDynamismStatic];
}

ExecuTorchTensor *BoolTensor(NSData *data, NSArray<NSNumber *> *shape) {
  return [[ExecuTorchTensor alloc]
      initWithBytesNoCopy:const_cast<void *>(data.bytes)
                    shape:shape
                  strides:@[]
           dimensionOrder:@[]
                 dataType:ExecuTorchDataTypeBool
            shapeDynamism:ExecuTorchShapeDynamismStatic];
}

ExecuTorchTensor *LongTensor(NSData *data, NSArray<NSNumber *> *shape) {
  return [[ExecuTorchTensor alloc]
      initWithBytesNoCopy:const_cast<void *>(data.bytes)
                    shape:shape
                  strides:@[]
           dimensionOrder:@[]
                 dataType:ExecuTorchDataTypeLong
            shapeDynamism:ExecuTorchShapeDynamismStatic];
}

NSData *CopyFloatTensor(ExecuTorchTensor *tensor, NSError **error) {
  ExecuTorchTensor *floatTensor = tensor;
  if (tensor.dataType != ExecuTorchDataTypeFloat) {
    floatTensor = [tensor copyToDataType:ExecuTorchDataTypeFloat];
  }
  if (floatTensor == nil || floatTensor.dataType != ExecuTorchDataTypeFloat) {
    if (error != nullptr) {
      *error = [NSError
          errorWithDomain:@"studio.peacockery.timbervox.keyboard.executorch"
                     code:1
                 userInfo:@{NSLocalizedDescriptionKey : @"ExecuTorch returned a non-float tensor."}];
    }
    return nil;
  }

  __block NSData *result = nil;
  [floatTensor bytesWithHandler:^(const void *pointer, NSInteger count,
                                  ExecuTorchDataType dataType) {
    result = [NSData dataWithBytes:pointer length:count * sizeof(float)];
  }];
  return result;
}

NSError *BridgeError(NSInteger code, NSString *description) {
  return [NSError
      errorWithDomain:@"studio.peacockery.timbervox.keyboard.executorch"
                 code:code
             userInfo:@{NSLocalizedDescriptionKey : description}];
}

} // namespace

@implementation TimberVoxExecuTorchBridge {
  ExecuTorchModule *_encoder;
  ExecuTorchModule *_refiner;
  ExecuTorchModule *_context;
  NSData *_contextExactEmbedding;
  NSData *_contextExactBias;
  NSData *_contextHashEmbedding;
  NSData *_contextHashBias;
  NSInteger _contextMaximumLength;
  NSInteger _contextExactWordCount;
  NSInteger _contextHashBucketCount;
  NSInteger _contextEmbeddingDimension;
}

- (instancetype)init {
  return [super init];
}

- (nullable instancetype)initWithEncoderPath:(NSString *)encoderPath
                                 refinerPath:(NSString *)refinerPath
                                       error:(NSError **)error {
  self = [super init];
  if (self == nil) {
    return nil;
  }

  _encoder = [[ExecuTorchModule alloc] initWithFilePath:encoderPath
                                               loadMode:ExecuTorchModuleLoadModeMmap];
  _refiner = [[ExecuTorchModule alloc] initWithFilePath:refinerPath
                                               loadMode:ExecuTorchModuleLoadModeMmap];
  if (![_encoder loadMethod:@"forward" error:error]) {
    return nil;
  }
  if (![_refiner loadMethod:@"forward" error:error]) {
    return nil;
  }
  return self;
}

- (nullable NSArray<NSData *> *)encoderOutputsWithFeatures:(NSData *)features
                                                keyCenters:(NSData *)keyCenters
                                                   keyMask:(NSData *)keyMask
                                                     error:(NSError **)error {
  ExecuTorchTensor *featureTensor = FloatTensor(features, @[@1, @2, @64]);
  ExecuTorchTensor *centerTensor = FloatTensor(keyCenters, @[@1, @64, @2]);
  ExecuTorchTensor *maskTensor = BoolTensor(keyMask, @[@1, @64]);
  NSArray<ExecuTorchValue *> *values =
      [_encoder executeMethod:@"forward"
                  withTensors:@[featureTensor, centerTensor, maskTensor]
                        error:error];
  if (values == nil || values.count < 3) {
    return nil;
  }

  NSMutableArray<NSData *> *outputs = [NSMutableArray arrayWithCapacity:3];
  for (NSInteger index = 0; index < 3; index += 1) {
    ExecuTorchTensor *tensor = values[index].tensorValue;
    if (tensor == nil) {
      return nil;
    }
    NSData *data = CopyFloatTensor(tensor, error);
    if (data == nil) {
      return nil;
    }
    [outputs addObject:data];
  }
  return outputs;
}

- (nullable NSData *)refinedEmissionsWithInput:(NSData *)input
                                          error:(NSError **)error {
  ExecuTorchTensor *inputTensor = FloatTensor(input, @[@1, @32, @92]);
  NSArray<ExecuTorchValue *> *values =
      [_refiner executeMethod:@"forward" withTensors:@[inputTensor] error:error];
  if (values == nil || values.count == 0 || values[0].tensorValue == nil) {
    return nil;
  }
  return CopyFloatTensor(values[0].tensorValue, error);
}

- (BOOL)loadContextModelAtPath:(NSString *)contextPath
                         error:(NSError **)error {
  _context = [[ExecuTorchModule alloc] initWithFilePath:contextPath
                                               loadMode:ExecuTorchModuleLoadModeMmap];
  if (![_context loadMethod:@"get_embeddings" error:error] ||
      ![_context loadMethod:@"forward" error:error]) {
    return NO;
  }

  NSArray<ExecuTorchValue *> *values =
      [_context executeMethod:@"get_embeddings" error:error];
  if (values == nil || values.count < 4) {
    if (error != nullptr) {
      *error = BridgeError(2, @"The context model did not return its embeddings.");
    }
    return NO;
  }
  NSMutableArray<ExecuTorchTensor *> *tensors =
      [NSMutableArray arrayWithCapacity:4];
  for (NSInteger index = 0; index < 4; index += 1) {
    ExecuTorchTensor *tensor = values[index].tensorValue;
    if (tensor == nil) {
      if (error != nullptr) {
        *error = BridgeError(3, @"The context model returned an invalid embedding tensor.");
      }
      return NO;
    }
    ExecuTorchTensor *floatTensor =
        tensor.dataType == ExecuTorchDataTypeFloat
            ? [tensor copy]
            : [tensor copyToDataType:ExecuTorchDataTypeFloat];
    if (floatTensor == nil) {
      if (error != nullptr) {
        *error = BridgeError(4, @"The context embedding could not be converted to floats.");
      }
      return NO;
    }
    [tensors addObject:floatTensor];
  }

  ExecuTorchTensor *exactEmbeddingTensor = tensors[0];
  ExecuTorchTensor *exactBiasTensor = tensors[1];
  ExecuTorchTensor *hashEmbeddingTensor = tensors[2];
  ExecuTorchTensor *hashBiasTensor = tensors[3];
  if (exactEmbeddingTensor.shape.count != 2 ||
      hashEmbeddingTensor.shape.count != 2) {
    if (error != nullptr) {
      *error = BridgeError(5, @"The context embedding shapes are invalid.");
    }
    return NO;
  }
  _contextExactWordCount = exactEmbeddingTensor.shape[0].integerValue;
  _contextEmbeddingDimension = exactEmbeddingTensor.shape[1].integerValue;
  _contextHashBucketCount = hashEmbeddingTensor.shape[0].integerValue;
  if (hashEmbeddingTensor.shape[1].integerValue !=
          _contextEmbeddingDimension ||
      exactBiasTensor.count != _contextExactWordCount ||
      hashBiasTensor.count != _contextHashBucketCount) {
    if (error != nullptr) {
      *error = BridgeError(6, @"The context embedding dimensions do not agree.");
    }
    return NO;
  }
  _contextExactEmbedding = CopyFloatTensor(exactEmbeddingTensor, error);
  _contextExactBias = CopyFloatTensor(exactBiasTensor, error);
  _contextHashEmbedding = CopyFloatTensor(hashEmbeddingTensor, error);
  _contextHashBias = CopyFloatTensor(hashBiasTensor, error);
  if (_contextExactEmbedding == nil || _contextExactBias == nil ||
      _contextHashEmbedding == nil || _contextHashBias == nil) {
    return NO;
  }

  ExecuTorchMethodMetadata *metadata =
      [_context methodMetadata:@"forward" error:error];
  ExecuTorchTensorMetadata *inputMetadata =
      metadata.inputTensorMetadata[@0];
  if (inputMetadata == nil || inputMetadata.shape.count < 2) {
    if (error != nullptr && *error == nil) {
      *error = BridgeError(7, @"The context model input shape is unavailable.");
    }
    return NO;
  }
  _contextMaximumLength = inputMetadata.shape[1].integerValue;
  return _contextMaximumLength > 0;
}

- (NSInteger)contextMaximumLength {
  return _contextMaximumLength;
}

- (NSInteger)contextExactWordCount {
  return _contextExactWordCount;
}

- (NSInteger)contextHashBucketCount {
  return _contextHashBucketCount;
}

- (nullable NSData *)contextScoresWithContextIds:(NSData *)contextIds
                                   contextHashes:(NSData *)contextHashes
                                contextWordCount:(NSInteger)contextWordCount
                                    candidateIds:(NSData *)candidateIds
                                 candidateHashes:(NSData *)candidateHashes
                                           error:(NSError **)error {
  if (_context == nil || _contextMaximumLength <= 0 ||
      _contextEmbeddingDimension <= 0) {
    if (error != nullptr) {
      *error = BridgeError(8, @"The context model is not loaded.");
    }
    return nil;
  }
  NSInteger candidateCount = candidateIds.length / sizeof(int64_t);
  if (contextIds.length != _contextMaximumLength * sizeof(int64_t) ||
      contextHashes.length != _contextMaximumLength * 2 * sizeof(int64_t) ||
      candidateIds.length % sizeof(int64_t) != 0 ||
      candidateHashes.length != candidateCount * 2 * sizeof(int64_t)) {
    if (error != nullptr) {
      *error = BridgeError(9, @"The context model input buffers have invalid sizes.");
    }
    return nil;
  }

  ExecuTorchTensor *idsTensor =
      LongTensor(contextIds, @[@1, @(_contextMaximumLength)]);
  ExecuTorchTensor *hashesTensor =
      LongTensor(contextHashes, @[@1, @(_contextMaximumLength), @2]);
  NSArray<ExecuTorchValue *> *values =
      [_context executeMethod:@"forward"
                  withTensors:@[idsTensor, hashesTensor]
                        error:error];
  if (values == nil || values.count == 0 || values[0].tensorValue == nil) {
    return nil;
  }
  ExecuTorchTensor *contextOutput = values[0].tensorValue;
  if (contextOutput.shape.count != 3 ||
      contextOutput.shape[1].integerValue < _contextMaximumLength ||
      contextOutput.shape[2].integerValue != _contextEmbeddingDimension) {
    if (error != nullptr) {
      *error = BridgeError(10, @"The context model output shape is invalid.");
    }
    return nil;
  }
  NSData *contextData = CopyFloatTensor(contextOutput, error);
  if (contextData == nil) {
    return nil;
  }

  NSInteger contextPosition = MAX(0, MIN(contextWordCount, _contextMaximumLength) - 1);
  const float *contextVector =
      static_cast<const float *>(contextData.bytes) +
      contextPosition * _contextEmbeddingDimension;
  const int64_t *wordIds = static_cast<const int64_t *>(candidateIds.bytes);
  const int64_t *wordHashes =
      static_cast<const int64_t *>(candidateHashes.bytes);
  NSMutableData *scoreData =
      [NSMutableData dataWithLength:candidateCount * sizeof(float)];
  float *scores = static_cast<float *>(scoreData.mutableBytes);

  const float *exactEmbedding =
      static_cast<const float *>(_contextExactEmbedding.bytes);
  const float *exactBias = static_cast<const float *>(_contextExactBias.bytes);
  const float *hashEmbedding =
      static_cast<const float *>(_contextHashEmbedding.bytes);
  const float *hashBias = static_cast<const float *>(_contextHashBias.bytes);
  if (exactEmbedding == nullptr || exactBias == nullptr ||
      hashEmbedding == nullptr || hashBias == nullptr) {
    if (error != nullptr) {
      *error = BridgeError(11, @"The context embeddings are unavailable.");
    }
    return nil;
  }

  for (NSInteger candidate = 0; candidate < candidateCount; candidate += 1) {
    int64_t wordId = wordIds[candidate];
    float score = 0;
    if (wordId >= 0 && wordId < _contextExactWordCount) {
      const float *embedding =
          exactEmbedding + wordId * _contextEmbeddingDimension;
      for (NSInteger dimension = 0;
           dimension < _contextEmbeddingDimension; dimension += 1) {
        score += contextVector[dimension] * embedding[dimension];
      }
      score += exactBias[wordId];
    } else {
      for (NSInteger hashIndex = 0; hashIndex < 2; hashIndex += 1) {
        int64_t bucket = wordHashes[candidate * 2 + hashIndex];
        if (bucket < 0 || bucket >= _contextHashBucketCount) {
          continue;
        }
        const float *embedding =
            hashEmbedding + bucket * _contextEmbeddingDimension;
        for (NSInteger dimension = 0;
             dimension < _contextEmbeddingDimension; dimension += 1) {
          score += contextVector[dimension] * embedding[dimension];
        }
        score += hashBias[bucket];
      }
    }
    scores[candidate] = score;
  }
  return scoreData;
}

@end
