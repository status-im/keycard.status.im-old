---
id: index
title: Getting Started
---

# Getting started

Keycard provides to developer an hardware implementation of a [BIP-32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) HD wallet. This means it supports key generation, derivation and signing. It also allows exporting keys defined in the context of [EIP-1581](https://eips.ethereum.org/EIPS/eip-1581).

Communication with the Keycard happens through a simple APDU interface is provided, together with a Secure Channel guaranteeing confidentiality, authentication and integrity of all commands. It supports both NFC and ISO7816 physical interfaces, meaning that it is compatible with any Android phone equipped with NFC and all USB Smartcard readers.

The most obvious case for integration of Keycard is crypto wallets (ETH, BTC, etc), however it can be used in other systems where a BIP-32 key tree is used and/or you perform authentication/identification.

To further simplify integration, we have developed a Java-based API which can be used on both desktop and Android systems. On the desktop it uses the javax.smartcardio to interface with the card, which is compatible with most USB readers. On Android it uses the on-board NFC reader. If you develop in Java or any other language available, this is the easiest way to use the Keycard. 

[Read the SDK documentation](java-sdk.html)

If you use a different language, please first refer to the [Java SDK](java-sdk.html) documentation for a high level overview of how to perform different tasks with the Keycard. Then, please check the [APDU protocol documentation](apdu.html) out for the low-level details.

## Versioning

The current version of the applet is 2.0. This documentation applies to said version. [Semantic versioning](https://semver.org) is used throughout the project, with the omission of the patch number for the applet, but not the SDK and related tools. The version of all components of the Keycard project are tied to the applet version.

## Installing, reinstalling and upgrading

If you got a Keycard and you are integrating it in your project, you will most likely want to reset the applet status completely for testing purposes. This is done by reinstalling the applet, which can be accomplished using the [Keycard Installer for Android](https://github.com/status-im/keycard-installer-android/releases).

Upgrading the applet is also accomplished with the installer and also involves deleting the current version. The latest version of the installer always ships with the latest version of the applet.

The installer has a simple interface, when you open it, you see a white screen and a few buttons. Select the operation you want to perform, then bring the card near to the NFC reader of your phone and wait until the operation is complete. Make sure NFC is turned on.

There are two operations used to install the applet. One is "Install Secure", which installs the applet without sending the INIT command, so the installed applet is not initialized. The other option is "Install with test PIN/PUK". This installs the applet and sets PIN to "000000", PUK to "123456789012" and Pairing Password to "KeycardTest". This second option is useful if you want to quickly test interaction without having to initialize the card in your application.

## Card requirements

The Keycard applet can be installed not only on our cards, but on any card which meets the following requirements:

* JavaCard 3.0.4 or later.
* Cipher.ALG_AES_BLOCK_128_CBC_NOPAD
* Cipher.ALG_AES_CBC_ISO9797_M2
* KeyAgreement.ALG_EC_SVDP_DH_PLAIN
* KeyAgreement.ALG_EC_SVDP_DH_PLAIN_XY (defined in JavaCard 3.0.5 but available on some 3.0.4 cards nonetheless)
* KeyPair.ALG_EC_FP (generation of 256-bit keys)
* MessageDigest.ALG_SHA_256
* MessageDigest.ALG_SHA_512
* RandomData.ALG_SECURE_RANDOM
* Signature.ALG_AES_MAC_128_NOPAD
* Signature.ALG_ECDSA_SHA_256

Best performance is achieved if the card supports:

* Signature.ALG_HMAC_SHA_512

Keycard requires about 10kb of NVM. All allocations, instantiations and checks are performed at installation time, so if installation succeeds, the applet will work fine.

## Resources

* [Keycard Installer for Android](https://github.com/status-im/keycard-installer-android/releases)
* [Latest Keycard Applet](https://github.com/status-im/keycard-installer-android/blob/master/app/src/main/assets/keycard.cap?raw=true)