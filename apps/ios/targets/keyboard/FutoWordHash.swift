import Foundation

enum FutoWordHash {
  private static let secret0: UInt64 = 0xa076_1d64_78bd_642f
  private static let secret1: UInt64 = 0xe703_7ed1_a0b4_28db
  private static let secret2: UInt64 = 0x8ebc_6af0_9c88_c6e3
  private static let secret3: UInt64 = 0x5899_65cc_7537_4cc3
  private static let multiplier0: UInt64 = 0x9e37_79b9_7f4a_7c15
  private static let multiplier1: UInt64 = 0x517c_c1b7_2722_0a95

  static func bucketIndices(for word: String, bucketCount: Int) -> [Int64] {
    guard bucketCount > 0, bucketCount.nonzeroBitCount == 1 else { return [0, 0] }
    let key = hash(Array(word.utf8))
    let shift = UInt64.bitWidth - bucketCount.trailingZeroBitCount
    return [
      Int64((multiplier0 &* key) >> shift),
      Int64((multiplier1 &* key) >> shift),
    ]
  }

  static func hash(_ bytes: [UInt8], seed initialSeed: UInt64 = 0) -> UInt64 {
    var seed = initialSeed ^ mix(initialSeed ^ secret0, secret1)
    let count = bytes.count
    let a: UInt64
    let b: UInt64

    if count <= 16 {
      if count >= 4 {
        a =
          (read4(bytes, at: 0) << 32)
          | read4(bytes, at: (count >> 3) << 2)
        b =
          (read4(bytes, at: count - 4) << 32)
          | read4(bytes, at: count - 4 - ((count >> 3) << 2))
      } else if count > 0 {
        a = read3(bytes)
        b = 0
      } else {
        a = 0
        b = 0
      }
    } else if count <= 48 {
      var offset = 0
      while offset + 16 <= count {
        seed = mix(
          read8(bytes, at: offset) ^ secret1,
          read8(bytes, at: offset + 8) ^ seed
        )
        offset += 16
      }
      a = read8(bytes, at: count - 16)
      b = read8(bytes, at: count - 8)
    } else {
      var offset = 0
      var secondSeed = seed
      var thirdSeed = seed
      while offset + 48 <= count {
        seed = mix(
          read8(bytes, at: offset) ^ secret1,
          read8(bytes, at: offset + 8) ^ seed
        )
        secondSeed = mix(
          read8(bytes, at: offset + 16) ^ secret2,
          read8(bytes, at: offset + 24) ^ secondSeed
        )
        thirdSeed = mix(
          read8(bytes, at: offset + 32) ^ secret3,
          read8(bytes, at: offset + 40) ^ thirdSeed
        )
        offset += 48
      }
      while offset + 16 <= count {
        seed = mix(
          read8(bytes, at: offset) ^ secret1,
          read8(bytes, at: offset + 8) ^ seed
        )
        offset += 16
      }
      seed ^= secondSeed ^ thirdSeed
      a = read8(bytes, at: count - 16)
      b = read8(bytes, at: count - 8)
    }

    return mix(secret1 ^ UInt64(count), mix(a ^ secret1, b ^ seed))
  }

  private static func mix(_ left: UInt64, _ right: UInt64) -> UInt64 {
    let product = left.multipliedFullWidth(by: right)
    return product.high ^ product.low
  }

  private static func read3(_ bytes: [UInt8]) -> UInt64 {
    (UInt64(bytes[0]) << 16)
      | (UInt64(bytes[bytes.count >> 1]) << 8)
      | UInt64(bytes[bytes.count - 1])
  }

  private static func read4(_ bytes: [UInt8], at offset: Int) -> UInt64 {
    (0..<4).reduce(UInt64.zero) { value, index in
      value | (UInt64(bytes[offset + index]) << (index * 8))
    }
  }

  private static func read8(_ bytes: [UInt8], at offset: Int) -> UInt64 {
    (0..<8).reduce(UInt64.zero) { value, index in
      value | (UInt64(bytes[offset + index]) << (index * 8))
    }
  }
}
