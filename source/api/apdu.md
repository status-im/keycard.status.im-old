# Status Keycard Protocol

These are the commands supported by the application. When a command has a precondition clause and these are not met the SW 0x6985 is returned. All tagged data structures are encoded in the [BER-TLV format](http://www.cardwerk.com/smartcards/smartcard_standard_ISO7816-4_annex-d.aspx) 

## SELECT

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

## INIT
* CLA = 0x80
* INS = 0xFE
* P1 = 0x00
* P2 = 0x00
* Data = EC public key (LV encoded) | IV | encrypted payload
* Response SW = 0x9000 on success, 0x6D00 if the applet is already initialized, 0x6A80 if the data is invalid

This command is only available when the applet is in pre-initialized state and successful execution brings the applet in the initialized state. This command is needed to allow securely storing secrets on the applet at a different moment and place than installation is taking place. Currently these are the PIN, PUK and pairing password.

The client must take the public key received after the SELECT command, generate a random keypair and perform EC-DH to generate an AES key. It must then generate a random IV and encrypt the payload using AES-CBC with ISO/IEC 9797-1 Method 2 padding.

They payload is the concatenation of the PIN (6 digits/bytes), PUK (12 digits/bytes) and pairing secret (32 bytes).

This scheme guarantees protection against passive MITM attacks. Since the applet has no "owner" before the execution of this command, protection against active MITM cannot be provided at this stage. However since the communication happens locally (either through NFC or contacted interface) the realization of such an attack at this point is unrealistic.

After successful execution, this command cannot be executed anymore. The regular SecureChannel (with pairing) is active and PIN and PUK are initialized.

## OPEN SECURE CHANNEL
* CLA = 0x80
* INS = 0x10
* P1 = the pairing index
* P2 = 0x00
* Data = An EC-256 public key on the SECP256k1 curve encoded as an uncompressed point.
* Response Data = A 256-bit salt and a 128-bit seed IV
* Response SW = 0x9000 on success, 0x6A86 if P1 is invalid, 0x6A80 if the data is not a public key

This APDU is the first step to establish a Secure Channel session. A session is aborted when the application is deselected, either directly or because of a card reset/tear.

The card generates a random 256-bit salt which is sent to the client. Both the client and the card do the following for key derivation

1. Use their private key and the counterpart public key to generate a secret using the EC-DH algorithm.
2. The generated secret, the pairing key and the salt are concatenated and the SHA-512 of the concatenated value is calculated.
3. The output of the SHA-512 algorithm is split in two parts of 256-bit. The first part is used as the encryption key and the second part is used as the MAC key for further communication.

The seed IV is used by the client as the IV for the next encrypted APDU.

## MUTUALLY AUTHENTICATE

* CLA = 0x80
* INS = 0x11
* P1 = 0x00
* P2 = 0x00
* Data = 256-bit random number
* Response Data = 256-bit random number
* Response SW = 0x9000 on success, 0x6985 if the previous successfully executed APDU was not OPEN SECURE CHANNEL, 0x6982 if authentication failed or the data is not 256-bit long

This APDU allows both parties to verify that the keys generated in the OPEN SECURE CHANNEL step are matching and thus guarantee authentication of the counterpart. The data sent by both parties is a 256-bit random number The APDU data is sent encrypted with the keys generated in the OPEN SECURE CHANNEL step. Each party must verify the MAC of the received APDU. If the MAC can be verified, it means that both parties are using the same keys. Only after this step has been executed the secure channel can be considered to be open and other commands can be sent. If the authentication fails the card must respond with 0x6982. In this case the OPEN SECURE CHANNEL command must be repeated to generate new keys.

## PAIR

* CLA = 0x80
* INS = 0x12
* P1 = pairing phase
* P2 = 0x00
* Data = see below
* Response Data = see below
* Response SW = 0x9000 on success, 0x6A80 if the data is in the wrong format, 0x6982 if client cryptogram verification fails, 0x6A84 if all available pairing slot are taken, 0x6A86 if P1 is invalid or is 0x01 but the first phase was not completed, 0x6985 if a secure channel is open

P1:
* 0x00: First step
* 0x01: Final step

Data:
* On first step: a 256-bit random client challenge
* On second step: the client cryptogram as SHA-256(shared secret, card challenge)

Response Data:
* On first step: the card cryptogram as SHA-256(shared secret, client challenge) followed by a 256-bit card challenge
* On second step: the pairing index followed by a 256-bit salt

This APDU is sent to pair a client. Pairing is performed with two commands which must be sent immediately one after the other. 

In the first phase the client sends a random challenge to the card. The card replies with the SHA-256 hash of the challenge and the shared secret followed by its random challenge. The client is thus able to authenticate the card by verifying the card cryptogram (since the client can generate the same and verify that it matches).

In the second phase the client sends the client cryptogram which is the SHA-256 hash of the shared secret and the card challenge. The card verifies the cryptogram and thus authenticates the client. On success the card generates a random 256-bit salt which is appended to the shared secret. The SHA-256 hash of the concatenated value is stored in the first available pairing slot and will be further used to derive session keys. The card responds with the pairing index (which the client must send in all OPEN SECURE CHANNEL commands) and the salt used to generate the key, so that the client can generate and store the same key.

The shared secret is a 256-bit value which must be be known to both parts being paired.

## UNPAIR

* CLA = 0x80
* INS = 0x13
* P1 = the index to unpair
* P2 = 0x00
* Response SW = 0x9000 on success, 0x6985 if security conditions are not met, 0x6A86 if the index is higher than the
  highest possible pairing index.
* Preconditions: Secure Channel must be opened, user PIN must be verified

This APDU is sent to unpair a client. An existing secure channel session must be open. The application implementing this protocol may apply additional restrictions, such as the verification of a user PIN. On success the pairing slot at the  given index will be freed and will be made available to pair other clients. If the index is already free nothing will happen.

## GET STATUS

* CLA = 0x80
* INS = 0xF2
* P1 = 0x00 for application status, 0x01 for key path status
* P2 = 0x00
* Response SW = 0x9000 on success, 0x6A86 on undefined P1
* Response Data = Application Status Template or Key Path
* Preconditions: Secure Channel must be opened

Response Data format:
if P1 = 0x00:
- Tag 0xA3 = Application Status Template
  - Tag 0x02 = PIN retry count (1 byte)
  - Tag 0x02 = PUK retry count (1 byte)
  - Tag 0x01 = 0xff if key is initialized, 0 otherwise

if P1 = 0x01:
- a sequence of 32-bit numbers indicating the current key path. Empty if master key is selected.

## SET NDEF

* CLA = 0x80
* INS = 0xF3
* P1 = 0x00
* P2 = 0x00
* Data = the data to store
* Response SW = 0x9000 on success, 0x6A80 on invalid data
* Preconditions: Secure Channel must be opened, PIN must be verified

Used to set the content of the data file owned by the NDEF applet. This allows changing the behavior of Android and other clients when tapping the card with no open client. As an example, it could be used to launch a specific wallet software.

The data is stored as is. A check is made that the first 2 bytes, read as a MSB first short, are equal to the Lc field minus 2 (the length of the field itself). This does not ensure that the NDEF record is valid, but ensures that no out of bound access happens.

## VERIFY PIN

* CLA = 0x80
* INS = 0x20
* P1 = 0x00
* P2 = 0x00
* Data = the PIN to be verified
* Response SW = 0x9000 on success, 0x63CX on failure, where X is the number of attempt remaining
* Preconditions: Secure Channel must be opened

Used to verify the user PIN. On correct PIN entry the card returns 0x9000, the retry counter is reset and the PIN is marked as authenticated for the entire session (until the application is deselected or the card reset/teared). On error, the number of remaining retries is decreased and the SW 0x63CX, where X is the number of available retries is returned. When the number of remaining retries reaches 0 the PIN is blocked. When the PIN is blocked this command always returns 0x63C0, even if the PIN is inserted correctly.

## CHANGE PIN

* CLA = 0x80
* INS = 0x21
* P1 = PIN identifier
* P2 = 0x00
* Data = the new PIN
* Response SW = 0x9000 on success, 0x6A80 if the PIN format is invalid, 0x6A86 if P1 is invalid
* Preconditions: Secure Channel must be opened, user PIN must be verified

Used to change a PIN or secret. In case of invalid format, the code 0x6A80 is returned. If the conditions match, the PIN or secret is updated. The no-error SW 0x9000 is returned.

P1:
* 0x00: User PIN. Must be 6-digits. The updated PIN is authenticated for the rest of the session. 
* 0x01: Applet PUK. Must be 12-digits.
* 0x02: Pairing secret. Must be 32-bytes long. Existing pairings are not broken, but new pairings will need to use the new secret.

## UNBLOCK PIN

* CLA = 0x80
* INS = 0x22
* P1 = 0x00
* P2 = 0x00
* Data = the PUK followed by the new PIN
* Response SW = 0x9000 on success, 0x6A80 if the format is invalid
* Preconditions: Secure Channel must be opened, user PIN must be blocked

Used to unblock the user PIN. The data field must contain exactly 18 numeric digits, otherwise SW 0x6A80 is returned. The first 12 digits are the PUK and the last 6 are the new PIN. If the PUK is correct the PIN is changed to the supplied one, it is unblocked and authenticated for the rest of the session. The status code 0x9000 is returned. When the PUK is wrong, the number of remaining retries is decreased and the SW 0x63CX, where X is the number of available retries is returned. When the number of remaining retries reaches 0 the PUK is blocked. When the PUK is blocked this command always returns 0x63C0, even if the PUK is inserted correctly. In this case the wallet is effectively lost.

## LOAD KEY

* CLA = 0x80
* INS = 0xD0
* P1 = key type
* P2 = 0x00
* Data = the key data
* Response SW = 0x9000 on success, 0x6A80 if the format is invalid, 0x6A86 if P1 is invalid
* Response Data = the key UID, defined as the SHA-256 of the public key
* Preconditions: Secure Channel must be opened, user PIN must be verified

P1:
* 0x01 = ECC SECP256k1 keypair
* 0x02 = ECC SECP256k1 extended keypair
* 0x03 = Binary seed as defined in [BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)

Data:

If P1 is 0x01 or 0x02
- Tag 0xA1 = keypair template
  - Tag 0x80 = ECC public key component (can be omitted)
  - Tag 0x81 = ECC private key component
  - Tag 0x82 = chain code (if P1=0x02)
  
If P1 is 0x03 a 64 byte sequence generated according to the BIP39 specifications is expected. The master key will be generated according to the [BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) specifications. This is only supported if the hardware supports public key derivation.

This command is used to load or replace the keypair used for signing on the card. This command always aborts open signing sessions, if any. Unless a DERIVE KEY is sent, a subsequent SIGN command will use this keypair for signature.

## DERIVE KEY

* CLA = 0x80
* INS = 0xD1
* P1 = derivation options
* P2 = 0x00
* Data = a sequence of 32-bit integers (most significant byte first). Empty if the master key must be used.
* Response SW = 0x9000 on success, 0x6A80 if the format is invalid, 0x6984 if one of the components in the path generates an invalid key, 0x6B00 if derivation from parent keys is selected but no valid parent key is cached.
* Preconditions: Secure Channel must be opened, user PIN must be verified (if no PIN-less key is defined), an extended keyset must be loaded

This command is used before a signing session to generate a private key according to the [BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) specifications. This command always aborts open signing sessions, if any. The generated key is used for all subsequent SIGN sessions. The maximum depth of derivation from the master key is 10. Any attempt to get deeper results in 0x6A80 being returned. The BIP32 specifications define a few checks which must be performed on the derived keys. If these fail, the 0x6984 is returned and the invalid key is discarded. A client should perform a GET STATUS command to get the actual current key path and resume derivation using a different path.

The ability to start derivation from the parent keys allows to more efficiently switch between children of the same key. Note however that only the immediate parent of the current key is cached so you cannot use this to go back in the hierarchy. If no valid parent key is available the status code 0x6B00 will be returned.

P1:
* bit 0-5 = reserved
* bit 7-6:
  - 00 derive from master keys
  - 01 derive from parent keys
  - 10 derive from current keys
  - 11 reserved

## GENERATE MNEMONIC

* CLA = 0x80
* INS = 0xD2
* P1 = checksum size (between 4 and 8)
* P2 = 0x00
* Response SW = 0x9000 on success. 0x6A86 if P1 is invalid.
* Response Data = a sequence of 16-bit integers (most significant byte first).
* Preconditions: Secure Channel must be opened

Used to generate a mnemonic according to the algorithm specified in [BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki). The returned data is a list of 16-byte integers which should be used as indexes in a wordlist to generate the human-readable mnemonic. Each integer can have a value from 0 to 2047.

## REMOVE KEY

* CLA = 0x80
* INS = 0xD3
* P1 = 0x00
* P2 = 0x00
* Response SW = 0x9000 on success.
* Preconditions: Secure Channel must be opened, user PIN must be verified

Removes the key from the card, bringing it back to an uninitialized state. No signing operation is possible after this command until a new LOAD KEY command is performed.

## GENERATE KEY

* CLA = 0x80
* INS = 0xD4
* P1 = 0x00
* P2 = 0x00
* Response SW = 0x9000 on success.
* Response Data = the key UID, defined as the SHA-256 of the public key
* Preconditions: Secure Channel must be opened, user PIN must be verified

Generates and stores keys completely on card. The state of the card after execution is the same as if a LOAD KEY command had been performed.

## DUPLICATE KEY

* CLA = 0x80
* INS = 0xD5
* P1 = subcommand
* P2 = depends on subcommand
* Data = depends on phase
* Response SW = 0x9000 on success.
* Response Data = depends on subcommand
* Preconditions: depends on subcommand

P1:
* 0x00: START DUPLICATE
* 0x01: ADD ENTROPY
* 0x02: EXPORT DUPLICATE
* 0x03: IMPORT DUPLICATE

### START DUPLICATE
This is the first step to start duplication. Requires an open secure channel and user PIN must be verified. Aborts any on-going duplication session. P2 is the number of entropy pieces to expect in total (including this command). The data contain the first piece of entropy. Returns no data. Must be performed with exactly the same parameters and data on all cards taking part in the duplication.

### ADD ENTROPY
This command uses the same one-shot secure channel scheme as defined in the INIT command. P2 is 00. Requires an ongoing duplicate session started with the START DUPLICATE subcommand. Must be performed once per device taking part in the duplication process, for a total number of devices equaling the P2 parameter of the START DUPLICATE subcommand (counting the device which sent the START DUPLICATE command as the first device). The data is a random 256-bit number. The same data must be sent to all the cards taking part in the duplication process.

### EXPORT DUPLICATE
This command must be sent to the card which you wish to duplicate. Requires an open secure channel and authenticated PIN. Works only if a duplication session is active and ADD ENTROPY has been performed the required number of times. Returns the encrypted duplicate of the master key and terminates the duplication session for this card. The format is exactly the same as the one defined in the LOAD KEY (TLV) command with omitted public key. It is however prepended by a 16-bytes IV and the entire TLV structure is encrypted.

### IMPORT DUPLICATE
This command must be sent to all the cards which are a target for duplication. The Data field must contain the output from the EXPORT DUPLICATE command performed on the source card. Returns the key UID. It follows exactly the same rules as the EXPORT DUPLICATE subcommand.

## SIGN

* CLA = 0x80
* INS = 0xC0
* P1 = 0x00
* P2 = 0x00
* Data = the hash to sign
* Response = public key and the signature
* Response SW = 0x9000 on success, 0x6A80 if the data is not 32-byte long
* Preconditions: Secure Channel must be opened, user PIN must be verified (or a PIN-less key must be active), a valid keypair must be loaded

Response Data format:
- Tag 0xA0 = signature template
  - Tag 0x80 = ECC public key component
  - Tag 0x30 = ECDSA Signature
    - Tag 0x02 = R value
    - Tag 0x02 = S value

Returns the ECDSA signature of the hash. The hash can be calculated using any algorithm, but must be 32-bytes long. The signature is returned in a signature template, containing the public key associated to the signature and the signature itself. For usage on the blockchain, you will need to calculate the recovery ID in addition to extracting R and S. To calculate the recovery ID you need to apply the same algorithm used for public key recovery from a transaction starting with a recovery ID of 0. If the public key matches the one returned in the template, then you have found the recovery ID, otherwise you try again by incrementing the recovery ID.

## SET PINLESS PATH

* CLA = 0x80
* INS = 0xC1
* P1 = 0x00
* P2 = 0x00
* Data = a sequence of 32-bit integers
* Response SW = 0x9000 on success, 0x6A80 if data is invalid
* Preconditions: Secure Channel must be opened, user PIN must be verified

Sets the given sequence of 32-bit integers as a PIN-less path. When the current derived key matches this path, SIGN will work even if no PIN authentication has been performed. An empty sequence means that no PIN-less path is defined.

## EXPORT KEY

* CLA = 0x80
* INS = 0xC2
* P1 = derivation options
* P2 = export options
* Response SW = 0x9000 on success, 0x6A86 if P1 or P2 are wrong
* Data = a sequence of 32-bit integers (empty if P1=0x00)
* Response Data = key pair template
* Response SW = 0x9000 on success, 0x6985 if the private key cannot be exported, 0x6A80 if the path is malformed
* Preconditions: Secure Channel must be opened, user PIN must be verified
  
P1:
0x00 = Current key
0x01 = Derive
0x02 = Derive and make current

P2:
0x00 = private and public key
0x01 = public key only
  
Response Data format:
- Tag 0xA1 = keypair template
  - Tag 0x80 = ECC public key component (could be omitted)
  - Tag 0x81 = ECC private key component (if P2=0x00)
  
This command exports the requested public and private key. The public key can be always exported (P2=0x01), but the private key (P2=0x00) can be exported if and only if the requested key path is in the [EIP-1581](https://eips.ethereum.org/EIPS/eip-1581) subtree. 

The P1 parameter indicates how to the derive the desired key. P1 = 0x00 indicates that the current key must be exported, and no derivation will be performed. P1 = 0x01 derives the path given in the data field without changing the current path of the card. P1 = 0x02 derives the path but also changes the current path of the card. The source for derivation can be set by OR'ing P1 with the constants defined in the DERIVE KEY command. This allows deriving from master, parent or current.

If the private key is being exported, the card could omit exporting the public key for performance reason. The public key can then be calculate off-card if needed.