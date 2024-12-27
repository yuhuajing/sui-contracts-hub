// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A basic ECDSA utility contract to do the following:
///
/// 1) Hash a piece of data using Keccak256, output an object with hashed data.
/// 2) Recover a Secp256k1 signature to its public key, output an
///    object with the public key.
/// 3) Verify a Secp256k1 signature, produce an event for whether it is verified.
module ecdsa_k1::example;

use sui::{ecdsa_k1, event};
use std::string::String;
use sui::hex;
use std::ascii;

// === Object Types ===

/// Object that holds the output data
public struct Output has key, store {
    id: UID,
    value: vector<u8>,
}

// == Event Types ===

/// Event on whether the signature is verified
public struct VerifiedEvent has copy, drop {
    is_verified: bool,
}

// === Public Functions ===

/// Hash the data using Keccak256, output an object with the hash to recipient.
public entry fun keccak256(data: String, recipient: address, ctx: &mut TxContext) {
    let hashed = Output {
        id: object::new(ctx),
        value: sui::hash::keccak256(data.as_bytes()),
    };
    // Transfer an output data object holding the hashed data to the recipient.
    transfer::public_transfer(hashed, recipient)
}

/// Recover the public key using the signature and message, assuming the signature was produced
/// over the Keccak256 hash of the message. Output an object with the recovered pubkey to
/// recipient.
public entry fun ecrecover(
    signature: vector<u8>,
    msg: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let pubkey = Output {
        id: object::new(ctx),
        value: ecdsa_k1::secp256k1_ecrecover(&signature, msg.as_bytes(), 0),
    };
    // Transfer an output data object holding the pubkey to the recipient.
    transfer::public_transfer(pubkey, recipient)
}

/// Recover the Ethereum address using the signature and message, assuming the signature was
/// produced over the Keccak256 hash of the message. Output an object with the recovered address
/// to recipient.
public entry fun ecrecover_to_eth_address(
    mut signature: vector<u8>,
    msg: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    // Normalize the last byte of the signature to be 0 or 1.
    let v = &mut signature[64];
    if (*v == 27) {
        *v = 0;
    } else if (*v == 28) {
        *v = 1;
    } else if (*v > 35) {
        *v = (*v - 1) % 2;
    };

    // Ethereum signature is produced with Keccak256 hash of the message, so the last param is
    // 0.
    let pubkey = ecdsa_k1::secp256k1_ecrecover(&signature, msg.as_bytes(), 0);
    let uncompressed = ecdsa_k1::decompress_pubkey(&pubkey);

    // Take the last 64 bytes of the uncompressed pubkey.
    let mut uncompressed_64 = vector[];
    let mut i = 1;
    while (i < 65) {
        uncompressed_64.push_back(uncompressed[i]);
        i = i + 1;
    };

    // Take the last 20 bytes of the hash of the 64-bytes uncompressed pubkey.
    let hashed = sui::hash::keccak256(&uncompressed_64);
    let mut addr = vector[];
    let mut i = 12;
    while (i < 32) {
        addr.push_back(hashed[i]);
        i = i + 1;
    };

    let addr_object = Output {
        id: object::new(ctx),
        value: addr,
    };

    // Transfer an output data object holding the address to the recipient.
    transfer::public_transfer(addr_object, recipient)
}

/// Verified the secp256k1 signature using public key and message assuming Keccak was using when
/// signing. Emit an is_verified event of the verification result.
public entry fun secp256k1_verify(signature: vector<u8>, public_key: vector<u8>, msg: String) {
    event::emit(VerifiedEvent {
        is_verified: ecdsa_k1::secp256k1_verify(&signature, &public_key, msg.as_bytes(), 0),
    });
}


public entry fun verify(sig: String, public_key: String, msg: String) {
    let signature = hex::decode(
        ascii::into_bytes(sig.to_ascii()),
    );
    let pk = hex::decode(
        ascii::into_bytes(public_key.to_ascii()),
    );
    event::emit(VerifiedEvent {
        is_verified: ecdsa_k1::secp256k1_verify(&signature, &pk, msg.as_bytes(), 0),
    });
}

#[test]
fun test_sign() {
    let msg = b"Hello world!";
    let pk = x"0475a3b9e2b8b14739f4e66adb08adb20200d5b2c24b53522574b782428b85bb8d10c6ba7134153f3c647b0aae73d5e2a1cb128ce0273e60f2fc030cb4d8dbb810";
    let sk = x"87d2ebd2b16a8796cf9521216a3ebc8ed6d573cf0a98552322e874c171179f6a";

    // Test with Keccak256 hash
    let sig = ecdsa_k1::secp256k1_sign(&sk, &msg, 0, false);
    assert!(ecdsa_k1::secp256k1_verify(&sig, &pk, &msg, 0));
    assert!(sig == x"d3e95eec136eb2c9d1ef7ff5ee6f1fd38897362175cd76899c0735a5112081445659834d3259146c03bbb75fa102b8066666466a4c2eef2e015b11969b479415");
    // assert!(verify(sig.to_string(), pk.to_string(), msg.to_string()));

    // // Test with SHA256 hash
    // let sig = ecdsa_k1::secp256k1_sign(&sk, &msg, 1, false);
    // assert!(ecdsa_k1::secp256k1_verify(&sig, &pk, &msg, 1));
    // assert!(sig == x"e5847245b38548547f613aaea3421ad47f5b95a222366fb9f9b8c57568feb19c7077fc31e7d83e00acc1347d08c3e1ad50a4eeb6ab044f25c861ddc7be5b8f9f");
    //
    // // Verification should fail with another message
    // let other_msg = b"Farewell, world!";
    // assert!(!ecdsa_k1::secp256k1_verify(&sig, &pk, &other_msg, 0));
}