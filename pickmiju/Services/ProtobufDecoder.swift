import Foundation

// MARK: - Yahoo Finance Protobuf Decoder
// Decodes the PricingData protobuf message from Yahoo Finance WebSocket
// Wire format: https://protobuf.dev/programming-guides/encoding/

struct PricingData {
    var id: String?
    var price: Float?
    var time: Int64?
    var currency: String?
    var exchange: String?
    var quoteType: Int32?
    var marketHours: Int32?
    var changePercent: Float?
    var dayVolume: Int64?
    var dayHigh: Float?
    var dayLow: Float?
    var change: Float?
    var shortName: String?
    var previousClose: Float?
    var openPrice: Float?
    var lastSize: Int64?
    var bid: Float?
    var bidSize: Int64?
    var ask: Float?
    var askSize: Int64?
    var priceHint: Int64?
    var vol24hr: Int64?
    var marketCap: Double?
    var circulatingSupply: Double?

    static func decode(from data: Data) -> PricingData? {
        var decoder = ProtobufReader(data: data)
        var result = PricingData()

        while let tag = decoder.readTag() {
            let fieldNumber = tag.fieldNumber
            let wireType = tag.wireType

            switch (fieldNumber, wireType) {
            // Field 1: id (string)
            case (1, 2):
                result.id = decoder.readString()
            // Field 2: price (float)
            case (2, 5):
                result.price = decoder.readFloat()
            // Field 3: time (sint64)
            case (3, 0):
                result.time = decoder.readSInt64()
            // Field 4: currency (string)
            case (4, 2):
                result.currency = decoder.readString()
            // Field 5: exchange (string)
            case (5, 2):
                result.exchange = decoder.readString()
            // Field 6: quote_type (int32)
            case (6, 0):
                result.quoteType = Int32(decoder.readVarint())
            // Field 7: market_hours (int32)
            case (7, 0):
                result.marketHours = Int32(decoder.readVarint())
            // Field 8: change_percent (float)
            case (8, 5):
                result.changePercent = decoder.readFloat()
            // Field 9: day_volume (sint64)
            case (9, 0):
                result.dayVolume = decoder.readSInt64()
            // Field 10: day_high (float)
            case (10, 5):
                result.dayHigh = decoder.readFloat()
            // Field 11: day_low (float)
            case (11, 5):
                result.dayLow = decoder.readFloat()
            // Field 12: change (float)
            case (12, 5):
                result.change = decoder.readFloat()
            // Field 13: short_name (string)
            case (13, 2):
                result.shortName = decoder.readString()
            // Field 15: open_price (float)
            case (15, 5):
                result.openPrice = decoder.readFloat()
            // Field 16: previous_close (float)
            case (16, 5):
                result.previousClose = decoder.readFloat()
            // Field 22: last_size (sint64)
            case (22, 0):
                result.lastSize = decoder.readSInt64()
            // Field 23: bid (float)
            case (23, 5):
                result.bid = decoder.readFloat()
            // Field 24: bid_size (sint64)
            case (24, 0):
                result.bidSize = decoder.readSInt64()
            // Field 25: ask (float)
            case (25, 5):
                result.ask = decoder.readFloat()
            // Field 26: ask_size (sint64)
            case (26, 0):
                result.askSize = decoder.readSInt64()
            // Field 27: price_hint (sint64)
            case (27, 0):
                result.priceHint = decoder.readSInt64()
            // Field 28: vol_24hr (sint64)
            case (28, 0):
                result.vol24hr = decoder.readSInt64()
            // Field 32: circulating_supply (double)
            case (32, 1):
                result.circulatingSupply = decoder.readDouble()
            // Field 33: market_cap (double)
            case (33, 1):
                result.marketCap = decoder.readDouble()
            default:
                // Skip unknown fields
                decoder.skipField(wireType: wireType)
            }
        }

        return result.id != nil ? result : nil
    }
}

// MARK: - Protobuf Wire Format Reader

private struct ProtobufReader {
    private let data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    var hasMore: Bool {
        offset < data.count
    }

    mutating func readTag() -> (fieldNumber: Int, wireType: Int)? {
        guard hasMore else { return nil }
        let value = readVarint()
        let wireType = Int(value & 0x07)
        let fieldNumber = Int(value >> 3)
        guard fieldNumber > 0 else { return nil }
        return (fieldNumber, wireType)
    }

    mutating func readVarint() -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                break
            }
            shift += 7
        }
        return result
    }

    mutating func readSInt64() -> Int64 {
        let value = readVarint()
        // ZigZag decoding: (n >>> 1) ^ -(n & 1)
        return Int64(bitPattern: (value >> 1) ^ (UInt64(bitPattern: -Int64(value & 1))))
    }

    mutating func readFloat() -> Float {
        guard offset + 4 <= data.count else { return 0 }
        var value: Float = 0
        withUnsafeMutableBytes(of: &value) { dest in
            dest.copyBytes(from: data[offset..<offset+4])
        }
        offset += 4
        return value
    }

    mutating func readDouble() -> Double {
        guard offset + 8 <= data.count else { return 0 }
        var value: Double = 0
        withUnsafeMutableBytes(of: &value) { dest in
            dest.copyBytes(from: data[offset..<offset+8])
        }
        offset += 8
        return value
    }

    mutating func readString() -> String? {
        let length = Int(readVarint())
        guard length > 0, offset + length <= data.count else { return nil }
        let stringData = data[offset..<offset+length]
        offset += length
        return String(data: stringData, encoding: .utf8)
    }

    mutating func skipField(wireType: Int) {
        switch wireType {
        case 0: // Varint
            _ = readVarint()
        case 1: // 64-bit
            offset = min(offset + 8, data.count)
        case 2: // Length-delimited
            let length = Int(readVarint())
            offset = min(offset + length, data.count)
        case 5: // 32-bit
            offset = min(offset + 4, data.count)
        default:
            break
        }
    }
}
