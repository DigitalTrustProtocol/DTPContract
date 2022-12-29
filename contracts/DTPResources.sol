// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.7;

// Types of claims

// The id of the trust is grouped

// -----------------
// trust
// validation
// confirmation / verification
// rating
// access
// identity.name
// identity.description
// identity.icon
// identity....(x identifiers)

// Type of subjects
// -----------------
// evm.address
// evm.contract

// context
// -----------------
// evm.chain.1

// scope
//



string constant tunnel = "Tunnel";
string constant trust1 = "Trust1";
string constant audit100 = "Audit100";

string constant contextChainEthereum = "crypto.evm.chain:1";

uint256 constant defaultLength = 512;

uint256 constant valueMaxLength = defaultLength;
uint256 constant scopeMaxLength = defaultLength;
uint256 constant contextMaxLength = defaultLength;
uint256 constant commentMaxLength = defaultLength;
uint256 constant linkMaxLength = defaultLength;

struct Claim {
    string typeId; // The cliam type. e.g. trust.1
    address issuer;
    address subject;
    string value; // 1,0,-1 (-x to +x) are the primary. Anything goes as its the typeId
    string scope; // the scope of the subject. E.g. contract, identity, ..., etc.
    string context; // The context of the claim. E.g. (crypto.evm.chain:1)
    string comment; // short message, including keywords (#). Safe?!
    string link; // link to a resource. Eg. a website or email etc.
    uint256 activate;
    uint256 expire;
}


struct FeeToken {
    bool accepted;
    uint256 fee;
}
