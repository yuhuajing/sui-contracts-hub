// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module nft::nft;

use std::string;
use sui::{event, url::{Self, Url}};

const ENotMatched: u64 =  0;
const ENotAllowTransfer: u64 = 1;
const ENotAuthorized: u64 = 2;
/// An example NFT that can be minted by anybody
public struct NFTMetaData has key, store {
    id: UID,
    /// Name for the token
    name: string::String,
    /// Symbol for the token
    symbol: string::String,
    /// Description of the token
    description: string::String,
    /// URL for the token
    baseurl: Url,
    // TODO: allow custom attributes
    sbt: bool,
    creator: address,
}

/// The OTW for the module.
public struct NFTId has key,store {
    id: UID,
    nftid: u64,
}

/// An example NFT that can be minted by anybody
public struct NFT has key, store {
    id: UID,
    metadata: ID,
    /// Name for the token
    name: string::String,
    /// Symbol for the token
    symbol: string::String,
    /// Description of the token
    description: string::String,
    /// URL for the token
    url: Url,
}

// ===== Events =====

public struct NFTMinted has copy, drop {
    // The Object ID of the NFT
    object_id: ID,
    // The creator of the NFT
    creator: address,
    // The name of the NFT
    name: string::String,
}

fun init( ctx: &mut TxContext) {
    let metadata = NFTMetaData {
        id: object::new(ctx),
        name: b"MY_NFT_NAME".to_string(),
        symbol: b"MY_NFT_SYMBOL".to_string(),
        description: b"This is the describscription".to_string(),
        baseurl: url::new_unsafe_from_bytes(b"https://api.coolcatsnft.com/cat/"),
        sbt: false,
        creator: ctx.sender(),
    };
    transfer::public_freeze_object(metadata);

    let nftid = NFTId{id: object::new(ctx), nftid:0};
    transfer::public_transfer(nftid, ctx.sender());
}

// ===== Public view functions =====

/// Get the NFT's `name,symbol`
public fun name(nft: &NFT): (&string::String,&string::String) {
    (&nft.name,&nft.symbol)
}

/// Get the NFT's `description`
public fun description(nft: &NFT): &string::String {
    &nft.description
}

/// Get the NFT's `url`
public fun url(nft: &NFT): &Url {
    &nft.url
}

/// Get the NFT's `url`
public fun sbt(nft: &NFTMetaData): bool {
    &nft.sbt==true
}

// ===== Entrypoints =====

#[allow(lint(self_transfer))]
/// Create a new devnet_nft
public entry fun owner_mint_to_sender(
    metadata: &NFTMetaData,
    nftid: &mut NFTId,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    assert!(sender == metadata.creator, ENotAuthorized);

    let mut targeturl = url::inner_url(&metadata.baseurl).to_string();
    let nowid = nftid.nftid.to_string();
    // append(String) adds the content to the end of the string
    targeturl.append(nowid);

    let nft = NFT {
        id: object::new(ctx),
        name: metadata.name,
        symbol: metadata.symbol,
        description: metadata.description,
        url: url::new_unsafe(targeturl.to_ascii()),
        metadata: object::id(metadata),
    };

    event::emit(NFTMinted {
        object_id: object::id(&nft),
        creator: sender,
        name: nft.name,
    });

    transfer::public_transfer(nft, sender);
    nftid.nftid = nftid.nftid + 1;
}

/// Transfer `nft` to `recipient`
public fun transfer(nft: NFT, meta: &NFTMetaData, recipient: address, _: &mut TxContext) {
    assert!(object::id(meta) == nft.metadata, ENotMatched);
    assert!(!meta.sbt, ENotAllowTransfer);
    transfer::public_transfer(nft, recipient)
}

/// Update the `description` of `nft` to `new_description`
public fun update_description(
    nft: &mut NFTMetaData,
    new_description: vector<u8>,
    _: &mut TxContext,
) {
    nft.description = string::utf8(new_description)
}

/// Permanently delete `nft`
public fun burn(nft: NFT, _: &mut TxContext) {
    let NFT { id, name: _, description: _, url: _ ,symbol:_,metadata:_} = nft;
    id.delete()
}
