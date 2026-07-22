#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TimberVoxExecuTorchBridge : NSObject

- (instancetype)init;

- (nullable instancetype)initWithEncoderPath:(NSString *)encoderPath
                                 refinerPath:(NSString *)refinerPath
                                       error:(NSError **)error;

- (nullable NSArray<NSData *> *)encoderOutputsWithFeatures:(NSData *)features
                                                keyCenters:(NSData *)keyCenters
                                                   keyMask:(NSData *)keyMask
                                                     error:(NSError **)error;

- (nullable NSData *)refinedEmissionsWithInput:(NSData *)input
                                          error:(NSError **)error;

- (BOOL)loadContextModelAtPath:(NSString *)contextPath
                         error:(NSError **)error;

@property(nonatomic, readonly) NSInteger contextMaximumLength;
@property(nonatomic, readonly) NSInteger contextExactWordCount;
@property(nonatomic, readonly) NSInteger contextHashBucketCount;

- (nullable NSData *)contextScoresWithContextIds:(NSData *)contextIds
                                   contextHashes:(NSData *)contextHashes
                                contextWordCount:(NSInteger)contextWordCount
                                    candidateIds:(NSData *)candidateIds
                                 candidateHashes:(NSData *)candidateHashes
                                           error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
