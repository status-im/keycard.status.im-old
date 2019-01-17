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

## Resources

* [Keycard Installer for Android](https://github.com/status-im/keycard-installer-android/releases)
* [Latest Keycard Applet](https://github.com/status-im/keycard-installer-android/blob/master/app/src/main/assets/keycard.cap?raw=true)