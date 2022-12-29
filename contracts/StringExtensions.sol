// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;



library StringExtensions {
    function bytes4Signature(string memory _str)
        internal
        pure
        returns (bytes4 encodedSignature_)
    {
        encodedSignature_ = bytes4(keccak256(bytes(_str)));
    }

    function utfStringLength(string memory self)
        internal
        pure
        returns (uint256 length)
    {
        uint256 i = 0;
        bytes memory string_rep = bytes(self);

        unchecked {
            while (i < string_rep.length) {
                if (string_rep[i] >> 7 == 0) i += 1;
                else if (string_rep[i] >> 5 == bytes1(uint8(0x6))) i += 2;
                else if (string_rep[i] >> 4 == bytes1(uint8(0xE))) i += 3;
                else if (string_rep[i] >> 3 == bytes1(uint8(0x1E)))
                    i += 4;
                    //For safety
                else i += 1;

                length++;
            }
        }
    }

    function escapeHTML(string memory input)
        internal
        pure
        returns (string memory)
    {
        bytes memory inputBytes = bytes(input);
        uint256 extraCharsNeeded = 0;

        for (uint256 i = 0; i < inputBytes.length; i++) {
            bytes1 currentByte = inputBytes[i];

            if (currentByte == "&") {
                extraCharsNeeded += 4;
            } else if (currentByte == "<") {
                extraCharsNeeded += 3;
            } else if (currentByte == ">") {
                extraCharsNeeded += 3;
            } else if (currentByte == "'") {
                extraCharsNeeded += 4;
            } else if (currentByte == "\"") {
                extraCharsNeeded += 4;
            }

        }

        if (extraCharsNeeded > 0) {
            bytes memory escapedBytes = new bytes(
                inputBytes.length + extraCharsNeeded
            );

            uint256 index;

            for (uint256 i = 0; i < inputBytes.length; i++) {
                if (inputBytes[i] == "&") {
                    escapedBytes[index++] = "&";
                    escapedBytes[index++] = "a";
                    escapedBytes[index++] = "m";
                    escapedBytes[index++] = "p";
                    escapedBytes[index++] = ";";
                } else if (inputBytes[i] == "<") {
                    escapedBytes[index++] = "&";
                    escapedBytes[index++] = "l";
                    escapedBytes[index++] = "t";
                    escapedBytes[index++] = ";";
                } else if (inputBytes[i] == ">") {
                    escapedBytes[index++] = "&";
                    escapedBytes[index++] = "g";
                    escapedBytes[index++] = "t";
                    escapedBytes[index++] = ";";
                } else if (inputBytes[i] == "'") {
                    escapedBytes[index++] = "&";
                    escapedBytes[index++] = "#";
                    escapedBytes[index++] = "3";
                    escapedBytes[index++] = "9";
                    escapedBytes[index++] = ";";
                } else if (inputBytes[i] == "\"") {
                    escapedBytes[index++] = "&";
                    escapedBytes[index++] = "a";
                    escapedBytes[index++] = "m";
                    escapedBytes[index++] = "p";
                    escapedBytes[index++] = ";";
                } else {
                    escapedBytes[index++] = inputBytes[i];
                }
            }
            return string(escapedBytes);
        }

        return input;
    }

    // Source: https://github.com/kieranelby/kingOfTheEtherThrone/blob/master/contracts/kingOfTheEtherThrone.sol
    // @notice Check if `_name` is a reasonable choice of name.
    // @return True if-and-only-if `_name_` meets the criteria
    // below, or false otherwise:
    //    - no fewer than 1 character
    //    - no more than 25 characters
    //    - no characters other than:
    //      - "roman" alphabet letters (A-Z and a-z)
    //      - western digits (0-9)
    //      - "safe" punctuation: ! ( ) - . _ SPACE
    //    - at least one non-punctuation character
    // Note that we deliberately exclude characters which may cause
    // security problems for websites and databases if escaping is
    // not performed correctly, such as < > " and '.
    // Apologies for the lack of non-English language support.
    function _validateText(
        string memory _text,
        uint256 minLength,
        uint256 maxLength
    ) internal pure returns (bool allowed) {
        bytes memory nameBytes = bytes(_text);
        uint256 lengthBytes = nameBytes.length;
        if (lengthBytes < minLength || lengthBytes > maxLength) {
            return false;
        }
        bool foundNonPunctuation = false;
        for (uint256 i = 0; i < lengthBytes; i++) {
            uint8 b = uint8(nameBytes[i]);
            if (
                (b >= 48 && b <= 57) || // 0 - 9
                (b >= 65 && b <= 90) || // A - Z
                (b >= 97 && b <= 122) // a - z
            ) {
                foundNonPunctuation = true;
                continue;
            }
            if (
                b == 32 || // space
                b == 33 || // !
                b == 40 || // (
                b == 41 || // )
                b == 45 || // -
                b == 46 || // .
                b == 95 // _
            ) {
                continue;
            }
            return false;
        }
        return foundNonPunctuation;
    }
}
