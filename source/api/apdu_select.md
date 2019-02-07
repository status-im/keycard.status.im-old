---
id: apdu_select
title: Protocol
---

# SELECT

* CLA = 0x00
* INS = 0xA4
* P1 = 0x04
* P2 = 0x00
* Data = the instance AID
* Response = Application Info Template or ECC public key.

Response Data format:
- Tag 0xA4 = Application Info Template
 - Tag 0x8F = Instance UID (16 bytes)
 - Tag 0x80 = ECC public Key
 - Tag 0x02 = Application Version (2 bytes)
 - Tag 0x02 = Number of remaining pairing slots (1 byte)
 - Tag 0x8E = Key UID (0 or 32 bytes)

The SELECT command is documented in the ISO 7816-4 specifications and is used to select the application on the card, making it the active one. The data field is the AID of the application. The response is the Application Info template which contains the instance UID (which can be used by the client to keep track of multiple cards) and the public key which must be used by the client to establish the Secure Channel. Additionally it contains the version number of the application, formatted on two bytes. The first byte is the major version and the second is the minor version (e.g: version 1.1 is formatted as 0x0101). The number of remaining pairing slots is also included in the response.

The Key UID can be either empty (when no key is loaded on card) or the SHA-256 hash of the master public key.

When the applet is in pre-initializated state, it only returns the ECC public key, BER-TLV encoded with tag 0x80.