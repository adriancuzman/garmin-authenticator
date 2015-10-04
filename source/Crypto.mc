module Crypto {

    class InvalidDataFormatException extends Toybox.Lang.Exception {
    }

    //------------------------------------------------------------------------
    // BASE-32 implementation
    //------------------------------------------------------------------------

    function base32decode(s) {
        var blockCount = s.length() / 8;
        if (s.length() % 8 != 0) {
            blockCount = blockCount + 1;
        }
        var lastBlock = decode32block(s.substring((blockCount - 1) * 8, blockCount * 8));
        var result = new[(blockCount - 1) * 5 + lastBlock.size()];
        for (var i = 0; i < blockCount - 1; ++i) {
            var block = decode32block(s.substring(i * 8, (i + 1) * 8));
            for (var j = 0; j < block.size(); ++j) {
                result[i * 5 + j] = block[j];
            }
        }
        for (var j = 0; j < lastBlock.size(); ++j) {
            result[(blockCount - 1) * 5 + j] = lastBlock[j];
        }
        return result;
    }

    function decode32block(block) {
        var result = [ 0, 0, 0, 0, 0 ];
        var blockLength = 0;
        for (var i = 0; i < block.length(); ++i) {
            var symbol = block.substring(i, i + 1);
            var bits = decode32digit(symbol);
            if (bits == -1) {
                if (symbol.find("=") != 0) {
                    throw new InvalidDataFormatException();
                } else {
                    break;
                }
            }
            var index = i * 5 / 8;
            var offset = i * 5 % 8;
            var currentSignificantBits = min(8 - offset, 5);
            var nextSignificantBits = 5 - currentSignificantBits;
            result[index] = result[index] + (bits >> nextSignificantBits) << (8 - currentSignificantBits - offset);
            if (nextSignificantBits != 0) {
                result[index + 1] = result[index + 1] + (bits % (1 << nextSignificantBits)) << (8 - nextSignificantBits);
            }
            blockLength = index + 1;
        }
        if (blockLength == 5) {
            return result;
        } else {
            var cutResult = new[blockLength];
            for (var i = 0; i < blockLength; ++i) {
                cutResult[i] = result[i];
            }
            return cutResult;
        }
    }

    function min(a, b) {
        if (a < b) { return a; }
        else { return b; }
    }

    function max(a, b) {
        if (a > b) { return a; }
        else { return b; }
    }

    hidden var patterns = [
        ["ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0],
        ["abcdefghijklmnopqrstuvwxyz", 0],
        ["234567", 26]
    ];

    function decode32digit(symbol) {
        for (var i = 0; i < 3; ++i) {
            var r = patterns[i][0].find(symbol);
            if (r != null) {
                return r + patterns[i][1];
            }
        }
        return -1;
    }

    //------------------------------------------------------------------------
    // SHA-1 implementation
    // see rfc3174 for details
    //------------------------------------------------------------------------

    hidden var mask32bit = 0xFFFFFFFFl;

    function sha1(data) {
        return sha1method1(data);
        // return [1l, 0l, 0l, 0l, 42l];
    }

    function getSha1Byte(data, index) {
        return data[(index / 4).toNumber()] >> (index % 4 * 8) % 256;
    }

    function clshift(x, n) {
        return ((x << n) & mask32bit) | (x >> (32 - n));
    }

    function sha1f(t, B, C, D) {
        if ((0 <= t) and (t <= 19)) {
            return (B & C) | ((~B) & D);
        } else if ((20 <= t) and (t <= 39)) {
            return B ^ C ^ D;
        } else if ((40 <= t) and (t <= 59)) {
            return (B & C) | (B & D) | (C & D);
        } else if ((60 <= t) and (t <= 79)) {
            return B ^ C ^ D;
        } else {
            throw new Toybox.Lang.Exception();
            return -1;
        }
    }

    function sha1k(t) {
        if ((0 <= t) and (t <= 19)) {
            return 0x5A827999l;
        } else if ((20 <= t) and (t <= 39)) {
            return 0x6ED9EBA1l;
        } else if ((40 <= t) and (t <= 59)) {
            return 0x8F1BBCDCl;
        } else if ((60 <= t) and (t <= 79)) {
            return 0xCA62C1D6l;
        } else {
            throw new Toybox.Lang.Exception();
            return -1;
        }
    }

    function padOne(wordBlock, position) {
        var wordId = position / 4;
        var offset = 3 - position % 4;
        wordBlock[wordId] = wordBlock[wordId] + (1l << 7) << (8 * offset);
    }

    function divCeil(a, b) {
        return (a % b == 0) ? a / b : a / b + 1;
    }

    function sha1method1(data) {
        var A, B, C, D, E;
        var H0 = 0x67452301l,
            H1 = 0xEFCDAB89l,
            H2 = 0x98BADCFEl,
            H3 = 0x10325476l,
            H4 = 0xC3D2E1F0l;
        var TEMP;
        var W = new[80];
        var blockSizeW = 16;
        var blockSizeB = blockSizeW * 4;
        var lastBlockDataBytes = data.size() % blockSizeB;
        var needAdditionalBlock = ((55 < lastBlockDataBytes) and (lastBlockDataBytes < 64)) or (lastBlockDataBytes == 0);
        var blockCount = needAdditionalBlock ? divCeil(data.size(), blockSizeB) + 1 : divCeil(data.size(), blockSizeB);
        var messageLength = data.size() * 8l;
        // for each 16-word (64-byte, 512-bit) block
        for (var i = 0; i < blockCount; ++i) {
            // a)
            for (var j = 0; j < 16; ++j) {
                W[j] = 0l;
            }
            var blockOffset = blockSizeB * i;
            var blockLimit = blockSizeB;
            if (i == blockCount - (needAdditionalBlock ? 2 : 1)) {
                blockLimit = lastBlockDataBytes;
            } else if (needAdditionalBlock and (i == blockCount - 1)) {
                blockLimit = 0;
            }
            for (var j = 0; j < blockLimit; ++j) {
                W[j / 4] = W[j / 4] + data[blockOffset + j].toLong() << (8 * (3 - j % 4));
            }
            // handle penult and last block padding
            if ((i == blockCount - 2) and needAdditionalBlock) {
                padOne(W, lastBlockDataBytes);
            } else if (i == blockCount - 1) {
                if (!needAdditionalBlock) {
                    padOne(W, lastBlockDataBytes);
                }
                W[14] = messageLength >> 32;
                W[15] = messageLength % (1l << 32);
            }
            // b)
            for (var t = 16; t <= 79; ++t) {
                W[t] = clshift(W[t-3] ^ W[t-8] ^ W[t-14] ^ W[t-16], 1);
            }
            // c)
            A = H0; B = H1; C = H2; D = H3; E = H4;
            // d)
            for (var t = 0; t <= 79; ++t) {
                TEMP = (clshift(A, 5) + sha1f(t, B, C, D) + E + W[t] + sha1k(t)) & mask32bit;
                E = D; D = C; C = clshift(B, 30); B = A; A = TEMP;
            }
            // e)
            H0 = (H0 + A) & mask32bit;
            H1 = (H1 + B) & mask32bit;
            H2 = (H2 + C) & mask32bit;
            H3 = (H3 + D) & mask32bit;
            H4 = (H4 + E) & mask32bit;
        }
        return [H4, H3, H2, H1, H0];
    }

    //------------------------------------------------------------------------
    // TOTP implementation
    // see rfc6238 for details
    //------------------------------------------------------------------------

    class TOTP {

        var decodedKey, // K
            epoch = 0, // T0
            interval = 30, // TI
            tokenLength = 6; // N

        function initialize(key) {
            decodedKey = base32decode(key);
        }


        function generateToken() {
            var c = (Time.now().value() - epoch) / interval;
            // Compute the HMAC hash H with C as the message and K as the key
            // (the HMAC algorithm is defined in the previous section, but also most cryptographical libraries support it).
            // K should be passed as it is, C should be passed as a raw 64-bit unsigned integer.
            var h = sha1(new[0]);
            var o = h[0] % 16; // 4 least significant bits
            // Take 4 bytes from H starting at O bytes MSB, discard the most significant bit and store the rest as an (unsigned) 32-bit integer, I.
            var tokenNumber =
                getSha1Byte(h, 19 - o) << (8 * 3) +
                getSha1Byte(h, 19 - o - 1) << (8 * 2) +
                getSha1Byte(h, 19 - o - 2) << (8 * 1) +
                getSha1Byte(h, 19 - o - 3);
            // The token is the lowest N digits of I in base 10. If the result has fewer digits than N, pad it with zeroes from the left.
            var format = "%0" + tokenLength + "i";
            var token = tokenNumber.format(format);
            if (token.length() > tokenLength) {
                return token.substring(token.length() - tokenLength, token.length());
            } else {
                return token;
            }
        }
    }

}