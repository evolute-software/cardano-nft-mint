# Simple NFT Minting Scripts

## How To Use

1. Clone this repo

   ```shell
   git clone https://github.com/spectrum-pool/nft-mint-cardano.git nmc
   ```

   This clones the repo into a folder called nmc on your computer.

1. Create your _project directory_ folder  
   This folder will contain all necessary files for the mint. 
   
   ```shell
   mkdir my-new-nft-mint
   ```

1. Create a key pair that will do the minting

   ```shell
   ./nmc/make-key.sh mainnet my-new-nft-mint
   ```

1. Generate a policy

   ```shell
   ./nmc/make-nft-policy.sh mainnet 10000 my-new-nft-mint 
   ```

1. Create a `nft-meta` file in `my-new-nft-mint` this is a typical `721`
   Cardano NFT metadata file. For an example see `example-nft-meta.json`.


           Note: the file MUST be named `nft-meta`. No filename extension. Not 
                 `nft-meta.json` not `nft-meta.txt`, just `nft-meta`. And it 
                  must be in your project directory (eg: `my-new-nft-mint`)

   ```shell
   touch my-new-nft-mint/nft-meta
   vim my-new-nft-mint/nft-meta 
   ```

1. Mint

   ```
   ./nmc/mint-nft.sh mainnet my-new-nft-mint TO_ADDR SVC_ADDR SVC_FEE_LV 
   ```

## Using With Existing Policy

Skip the steps `make-key.sh` and `make-nft-policy`.
Instead copy your vkey, skey and a file containing an address to that wallet
into your _project directory_. 
