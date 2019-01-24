---
id: java-sdk
title: Keycard Java SDK 2.0
---

## Installation

You can import the SDK in your Gradle or Maven project using [Jitpack.io](https://jitpack.io). If using Gradle, to use
JitPack all you have to do is insert these lines in you `build.gradle` file

```groovy
allprojects {
  repositories {
    maven { url 'https://jitpack.io' }
  }
}
```

Then, you must import the correct dependency. In case you are building an Android-based project, you need to add this line

```groovy
dependencies {
  implementation 'com.github.status-im.status-keycard-java:android:2.0.0'
}
```

If you are working on the desktop, then you need this line instead

```groovy
dependencies {
  implementation 'com.github.status-im.status-keycard-java:desktop:2.0.0'
}
```

In both case, you will have the same SDK, except for the way connection with the card is established.

## Connecting to the card (Android)

On Android, the NFC connection handling must happen on a thread separate from the UI thread. The SDK provides the class `NFCCardManager` to handle this. This an example activity starting the NFC reader and handling the connection to the card. Refer to the comments in the example for more information.

```java
public class MainActivity extends AppCompatActivity {
  private NfcAdapter nfcAdapter;
  private NFCCardManager cardManager;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_main);
    
    // Get the Android NFC default adapter
    nfcAdapter = NfcAdapter.getDefaultAdapter(this);
    
    // Create the NFCCardManager, this class is provided by the Keycard SDK and handles connections to the card
    cardManager = new NFCCardManager();

    // The Card Listener receives the connected/disconnected events. These can happen at any time since the user can
    // introduce or remove the card to/from the field at any time. This is where your code goes.
    cardManager.setCardListener(new CardListener() {
      @Override
      public void onConnected(CardChannel cardChannel) {
        // Card is connected. Here you can start working with the Keycard. The CardChannel is what you will use to
        // communicate with the card.
      }

      @Override
      public void onDisconnected() {
        // Card is disconnected (was removed from the field). You can perform cleanup here.
      }
    });
    cardManager.start();
  }

  @Override
  public void onResume() {
    super.onResume();
    
    // We need to enable the reader on resume.
    if (nfcAdapter != null) {
      nfcAdapter.enableReaderMode(this, this.cardManager, NfcAdapter.FLAG_READER_NFC_A | NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK, null);
    }
  }

  @Override
  public void onPause() {
    super.onPause();
    
    // We disable the reader on pause to allow other apps to use it.
    if (nfcAdapter != null) {
      nfcAdapter.disableReaderMode(this);
    }
  }
}
```

## Connecting to the card (Desktop)

On the desktop we use the javax.smartcardio library. There are several ways to handle connections, the important part is getting a CardChannel open. Below is an example of how this can be achieved (assumes that a single smartcard reader is connected).

```java
// We create a TerminalFactory object
TerminalFactory tf = TerminalFactory.getDefault();
CardTerminal cardTerminal;

// We search a terminal with a card inside
for (CardTerminal t : tf.terminals().list()) {
if (t.isCardPresent()) {
  cardTerminal = t;
  break;
    }
  }
}

// If not found, we throw an exception. Of course you should decide how to handle this situation
if (cardTerminal == null) {
  throw new RuntimeException("No terminal found");
}

// If a terminal is found, we connect to it
Card apduCard = cardTerminal.connect("*");

// We create a PCSCCardChannel, which is an implementation of CardChannel and can be used with the rest of the SDK.
PCSCCardChannel apduChannel = new PCSCCardChannel(apduCard.getBasicChannel());
```

## Working with the card

Regardless whether you are on Android or desktop, you should at this point have an implementation of the CardChannel interface (be it NFCCardChannel or PCSCCardChannel). You can now start working with the card. The first thing to do is creating a `KeycardCommandSet` instance. This class gives access to all of the applet functionality, wrapping the low-level APDUs in easy to use methods. All other classes in the SDK are helper to format parameters and parse responses from the card. To create a command set, just do

```java
// cardChannel is our CardChannel instance
KeycardCommandSet cmdSet = new KeycardCommandSet(cardChannel);
```

Modern SmartCards can have several applications installed, so after connection with the card you need to select the Keycard applet. This is easily done with

```java
// The checkOK method can be called on any APDUResponse object to confirm that the
cmdSet.select().checkOK();
```

While this correctly selects the applet, it discards the card response, which contains information that can be useful to identify this specific card and its state. For this reason we could rewrite this as

```java
ApplicationInfo info = new ApplicationInfo(cmdSet.select().checkOK().getData());

// This method tells if the card is initialized (has a PIN, PUK and pairing password). If it is not, it must be
// initialized and no other operation is possible. Note that initialization touches only credentials to authenticate
// the user or the client, but does not touch the creation of a wallet on the card
info.isInitializedCard();

// Returns the instance UID of the applet. This can be used to identify this specific applet instance, very
// useful when storing instance-specific data on the client (pairing info, cached data, etc).
info.getInstanceUID();

// Returns the version of the applet.
info.getAppVersion();

// Returns the number of free pairing slots. If you are not yet paired with the card, it helps you know if you can still
// pair or not
info.getFreePairingSlots());

// Tells if the card has a wallet or not. If no wallet is available, you must create once before you can perform most
// operations on the card
info.hasMasterKey();

// Returns the UID of the master key of the wallet. The UID is value generated starting from the public key and is 
// useful to identify if the card has the expected wallet.
info.getKeyUID();
```

After the applet is selected, you can start working with it. Note that the application remains selected until another applet is explicitly selected, or the card is powered off (for example is removed from the field)

### Initialization

This step is necessary to bring the initial credentials on the Keycard instance. When the card is not initialized, it cannot perform any operation. Initialization sets the initial PIN, PUK and pairing password and requires no authentication, but still uses a SecureChannel resistant to passive MITM attacks. Once the card is initialized, it cannot be initialized again (but credentials can be different with a different mechanism with previous authentication).

Initialization is done with

```java
// Usually, you want to check if the card is initialized before trying to initialize it, otherwise you will receive an
// error.
if (!info.isInitializedCard()) {
  // The PIN must be 6 digits, the PUK 12 digits and the pairing password can be any password. 
  // All parameters are strings
  cmdSet.init(pin, puk, pairingPassword).checkOK();
}
```

### Pairing

Clients wishing to communicate with the card, need to pair with it first. This allows creating secure channels resistant not only to passive but also to active MITM attacks. Although pairing allows the card and the client to authenticate each other, the card does not grant access to any operation with the wallet until the user is authenticated (by verifying its PIN). To establish the pairing, the client needs to know the pairing password. After it is established, the pairing info (not the password) must be stored as securely as possible on the client for subsequent sessions. You should store the pairing information together with the instance UID to simplify handling of multiple cards.

Only 5 clients can be paired at once, but it is possible to unpair previously paired clients.

Using the SDK, pairing is a simple operation

```java
// pairingPassword is usually provided by the user. This method throws an exception if pairing fails.
cmdSet.autoPair(pairingPassword);
// Retrieves the pairing object from the command set. This is what must be persisted (together with the instance UID)
Pairing pairing = cmdSet.getPairing();
// The pairing object can be serialized by calling
pairing.toByteArray();
// or the convenience method
pairing.toBase64();
```

If you have already paired, you should instead load the persisted pairing information in the command set

```java
// serializedPairing can be either the byte array or base64 string representation
Pairing pairing = new Pairing(serializedPairing);
// Sets the pairing info in the command set. This must be done before further operation is possible
cmdSet.setPairing(pairing);
```

### Secure Channel

After a pairing has been established, a secure channel can be opened. Before opening a secure channel, the card won't allow sending any command. This guarantees secrecy, integrity and authenticity of the commands. Opening a secure channel must be performed every time the applet is selected (this means also after a power loss). After opening it, the SDK handles the secure channel transparently, encrypting and signing all command APDUs and decrypting and verifying the signature of all responses. To open a secure channel all you need to do is

```java
cmdSet.autoOpenSecureChannel();
```

### Authenticating the user

Most operations with the card (all involving operations with the wallet or credentials) require authenticating the user. After authentication, the user remains authenticated until the card is powered off or the application is re-selected.

Authentication is performed by verifying the user PIN. Note that this piece of information is sensitive and must be handled accordingly in the application. PIN verification is done with a single step

```java
// pin is the user PIN as a string of 6 digits
try {
  cmdSet.verifyPIN(pin).checkAuthOK();
} catch(WrongPINException e) {
  System.out.println("Number of remaining attempts: " + e.getRetryAttempts());
}
```

if the PIN is wrong, you will receive an error SW in the format 0x63CX where X is the number of attempts remaining. When the number of remaining attempts is 0, the card is blocked. The user must then enter the PUK and a new PIN to restore access to the card. The maximum number of retries for the PUK is 5. To simplify things, the `APDUResponse.checkAuthOK()` method can be used to verify if the authentication was correct, and if not throw a `WrongPINException` which contains the number of remaining attempts.

```java
cmdSet.unblockPIN(puk, newPIN).checkAuthOK();
```

## Creating a wallet

To actually use the Keycard, it needs to have a wallet. This can be achieved in several different ways, which one you choose depends on your usage scenario. Creating a wallet requires user authentication and is possible even if a wallet already exists on the card (the new wallet replaces the old one). Use the `ApplicationInfo.hasMasterKey()` method to determine if the card already has a wallet or not. Note that the response of the `KeycardCommandSet.loadKey` method contains the key UID of the created wallet. This UID can be stored to keep track of this specific wallet in the client. The UID is tied to the key itself (is derived from the public key) so it will change if the wallet on card is replaced. The key UID is also part of the response of the applet selection command, so the wallet can be identified immediately upon selection.

### Creating a BIP39 mnemonic phrase

This method is great for interoperability with other wallets. The card can assist in creating the mnemonic phrase, since it features a TRNG. Generating the mnemonic itself does not require user authentication (since it does not modify the card state), but loading the key derived from it does. Example of the entire procedure is below

```java
// Generates a Mnemonic object from the card. You can choose between generating 12, 15, 18, 21 or 24 words
Mnemonic mnemonic = new Mnemonic(cmdSet.generateMnemonic(KeycardCommandSet.GENERATE_MNEMONIC_12_WORDS).checkOK().getData());

// We need to set a wordlist if we plan using this object to derive the binary seed. We can set our own list or we can
// fatch the official BIP39 english word list as shown below.
mnemonic.fetchBIP39EnglishWordlist();

// If we did not verify the PIN before, we can do it now
cmdSet.verifyPIN(pin).checkOK();

// Loads the key generated from the mnemonic phrase.
cmdSet.loadKey(mnemonic.toBIP32KeyPair()).checkOK();
```

### Importing a wallet from BIP39 mnemonic phrase

Importing an existing passphrase requires only the loading step.

```java
// The passphrase is a string with space separated words. The password can be any non-null string, usually is empty.
cmdSet.loadKey(Mnemonic.toBinarySeed(passphrase, password)).checkOK();
```

### Generating keys on-card

This is the simplest and safest method, because the generated wallet never leaves the card and there is no "paper backup" to keep secure. It is possible to create secure duplicates of the wallet on other Keycards, with a mechanism described in later chapters. Using the SDK, you simply do

```java
cmdSet.generateKey().checkOK();
```

### Importing an EC keypair

You can import on the keycard any EC keypair on the SECP256k1 curve, with or without the BIP32 extension. If your import a key without the BIP32 extension, then key derivation will not work, but you will still be able to use the Keycard for signing transactions using the imported key. This scenario can be useful if you are migrating from a wallet not using BIP39 passphrases or for wallets following some custom generation rules. It is however generally preferable to use one of the methods presented above.

An example of key import is

```java
// privKey is the S component of the key, as a 32-byte long byte array
// chainCode is the extension to the keypair defined by BIP32, this is another 32-byte long byte array. Can be null, in
// which case the created wallet won't be BIP32 compatible.
// pubKey is the DER encoded, uncompressed public key. Can be null, in which case it is automatically calculated from
// the private key.
BIP32KeyPair keypair = new BIP32KeyPair(privKey, chainCode, pubKey);

// Loads the keypair
cmdSet.loadKey(keypair).checkOK();
```

## Key derivation

As mentioned before, the Keycard is a BIP32 compatible wallet. This means that it can perform key derivation as defined by the BIP32 specification in order to create a hierarchical deterministic wallet. When deriving a key, this key becomes active, which means that it will be used for all signing operations until a key with a different path is derived. The active key is persisted across sessions, meaning that a power loss or applet reselection does not reset it.

When creating or importing a wallet to the Keycard, the active key is the master key. Unless you imported a non-BIP32 compatible wallet, you usually want to set the active key to a currency account by following the BIP44 specifications for paths. Note that the maximum depth of the key path is 10, excluding the master key.

Key derivation requires user authentication

Since a line of code is worth a thousand words, below is an example of deriving a standard key path

```java
cmdSet.deriveKey("m/44'/0'/0'/0/0").checkOK();
```

Since deriving a key is an expensive operation, you usually want to know what the current path is before performing derivation. You can do this with

```java
// you can then get is as a string with currentPath.toString()
KeyPath currentPath = new KeyPath(cmdSet.getStatus(KeycardCommandSet.GET_STATUS_P1_KEY_PATH).checkOK().getData());
```

To speed up operations, key derivation can be started not only from the master key, but also from the parent or the current key. The path in this case starts respectively with "../" and "./". You cannot navigate the hierarchy with multiple ".." in the paths, because only the direct parent of the current key is cached. Derivation from parent is especially convenient when switching between accounts of the same type. Example

```java
// Derive the main account
cmdSet.deriveKey("m/44'/0'/0'/0/0").checkOK();

// switch a secondary account, equivalent to "m/44'/0'/0'/0/1" but much faster
cmdSet.deriveKey("../1").checkOK();

// you can switch back and forth between siblings without limitations.
cmdSet.deriveKey("../0").checkOK();
```

## Signing

Your Keycard has been initialized, has a wallet and you have derived the keypath you need. You can now perform transactions by signing them with the card. Since the Keycard has no user input/output capabilities, it would be useless to transfer the entire transaction to the card for signing. You should instead calculate the transaction hash, according to the rules of the cryptocurrency you are handling and send that for signature instead. This also means, that you can handle anything which requires ECDSA signatures over SECP256k1 curve, regardless of the used hashing algorithm (at the condition that it output a 256-bit hash of course). This opens the door to signing transactions for the most common cryptocurrencies, but also makes it usable outside the realm of crypto transactions.

Signing is done as

```java
// hash is the hash to sign, for example the Keccak-256 hash of an Ethereum transaction
// the signature object contains r, s, recId and the public key associated to this signature
RecoverableSignature signature = new RecoverableSignature(hash, cmdSet.sign(hash).checkOK().getData());
```

Signing requires user authentication.

## Exporting (public or EIP-1581 compliant) keys

Sorry for the long title, but let's make it immediately clear: the keys used to sign transactions never leave the card and cannot be exported. You can however export any public key as well as the private key of keypaths defined in the [EIP-1581 specifications](https://eips.ethereum.org/EIPS/eip-1581). Those keys, by design, are not to be used for transactions but are instead usable for operations with lower security concerns where caching or storing the key outside the card might be beneficial from an UX point of view. Of course, exporting a key always requires user authentication.

### Exporting the current key

```java
// Exports the current public key. This is allowed for any key path
BIP32KeyPair publicKey = BIP32KeyPair.fromTLV(cmdSet.exportCurrentKey(true).checkOK().getData());

// Exports the entire key pair. This is only allowed for key path following the EIP-1581 definition
BIP32KeyPair keypair = BIP32KeyPair.fromTLV(cmdSet.exportCurrentKey(false).checkOK().getData());
```

### Derive & export

The export command is very powerful, since it allows you to derive & export a key in one step. You have the option to make the derived and exported key active or leave the active key untouched. You can also decide whether to export only the public key or the entire keypair (following the rules defined above).

A very convenient use case is deriving an account key and retrieving the public key in one step. This is faster than doing it with two commands (derive key and export public), because every command processed has some overhead. Example

```java
// The first parameter is the keypath, the second tells whether that you want to make the derived & exported key active
// and the third tells that you only want the public key to be exported.
BIP32KeyPair publicKey = BIP32KeyPair.fromTLV(cmdSet.exportKey("m/44'/0'/0'/0/0", true, true).checkOK().getData());

// The line above is equivalent to
// cmdSet.deriveKey("m/44'/0'/0'/0/0").checkOK();
// BIP32KeyPair publicKey = BIP32KeyPair.fromTLV(cmdSet.exportCurrentKey(true).checkOK().getData());
```

Another use case, is to export keys defined by EIP-1581 without changing the current active key, since you won't be signing with the exported key using the card

```java
// Let's assume the current active path is "m/44'/0'/0'/0/0"

// The first parameter is the key path, the second tells that you do not want to make it current and the third that you
// want the entire keypair, not only the public key
BIP32KeyPair keypair = BIP32KeyPair.fromTLV(cmdSet.exportKey("m/43'/60'/1581'/0'/0", false, false).checkOK().getData());

// At this point, the current active path would still be "m/44'/0'/0'/0/0"
```

## Changing credentials

All credentials of the Keycard can be changed (PIN, PUK, pairing password). Changing the pairing password does not invalidate existing pairings, but applies to the ones which can be created in the future. Changing credentials, requires user authentication.

```java
// Changes the user PIN
cmdSet.changePIN("123456").checkOK();

// Changes the PUK
cmdSet.changePUK("123456123456").checkOK();

// Changes the pairing password
cmdSet.changePairingPassword("my pairing password").checkOK();
```

## Duplication

Card duplication is especially relevant when the keys have been generated on-card, without using BIP39 mnemonic (or when this has been destroyed). To make duplication secure the client must not possess the (full) encryption key. For this reason, a scheme where multiple clients are used and none of them has the full key has been devised. From the user point of view, the duplication process goes like this

1. Take the card to be duplicated (source) and one or more cards to duplicate to (target)
2. On one of the user's clients initiate the duplication. This involves entering the PIN of each of the involved cards
3. Tap all cards to one or more additional clients (the amount must be defined before, the order is irrelevant). These clients do not need to be paired or be trusted, so the user can borrow a friend's phone without compromising security. This step does not require entering a PIN
4. On one of the user's clients, usually the same which initiated the duplication (must be paired, trusted) finalize the duplication by first tapping the source card and then all target cards, again inserting the PIN for each.
   
At the end of procedure, each card will have the same master key, but PIN, PUK and pairing key remain unchanged and are independent from each other. A client could propose changing them to be all the same if desired or do this automatically. All cards are fully functional, so at this point there isn't any difference between the source card and the targets.

Since the cards are still protected by the PIN, these can be stored remotely in moderately trusted places to recover from lost or destroyed cards. The duplication has been performed securely since no client ever had the full encryption key and no authentication credentials has been inserted on untrusted clients. For flexibility reason, an arbitrary number of clients can be used. Using a single client could be convenient from an UX point of view, but relies on said client not being compromised. Using 2 or 3 clients greatly increases security. More than 3 clients is probably an overkill.

From an implementation point of view, we have two different roles a client can take

1. The trusted client, starting and performing the duplication
2. The (possibly) untrusted clients, only adding entropy to the encryption key

Both can be implemented by using the `CardDuplicator` class. On each client, the same instance of the `CardDuplicator` class must be used for the entire duplication process, otherwise duplication will fail.

The trusted client must also provide an implementation of `DuplicatorCallback`. This is needed to retrieve the Pairing and PIN for each card. Example below

```java
class MyDuplicatorCB implements DuplicatorCallback {
  Pairing getPairing(ApplicationInfo applicationInfo) {
    // The Instance UID is the one to use when storing/retrieving pairings
    byte[] uid = applicationInfo.getInstanceUID();
    
    // Using the UID try to retrieve the pairing. The method getSavedPairing is an example and is not part of the SDK,
    // you are responsible of how you store and retrieve pairing data in your app
    Pairing pairing = getSavedPairing(uid);
    
    // Optionally, you could prompt the user and make a new pairing if none if given, but this is an UX decision in
    // your application.
    if (pairing == null) {
      pairing = tryToPair();
    }
    
    // possibly null, in this case the operation requiring pairing is aborted
    return pairing;
  }
  
  String getPIN(ApplicationInfo applicationInfo, int remainingAttempts) {
    // Optionally, you might have a cache of PINs for recently used card, but this should be done carefully as the PIN
    // is sensitive data. You might instead want to just prompt the user each time.
    String pin = getCachedPIN(applicationInfo.getInstanceUID());
    
    if (pin == null) {
      // prompt the user to insert the PIN. You can optionally inform them about how many retry attempts are left.
      // For UX reason you could also use the instance UID to show the user an identifiable name, this is again
      // application specific.
      pin = promptUser(remainingAttempts);
    }
    
    // This must not be null. PIN verification will be performed by the CardDuplicator itself, do no not perform it here!
    return pin;
  }
}
```

The next step to do, is instantiating a CardDuplicator.

For the trusted client

```java
// The cmdSet is a KeycardCommandSet instance, duplicatorCallback is an object implementing the DuplicatorCallback
// interface
cardDuplicator = new CardDuplicator(cmdSet, duplicatorCallback);
```

For the untrusted clients

```java
// apduChannel is a CardChannel instance. Alternatively the same constructor as for the trusted client can be used,
// passing null as the second parameter.
cardDuplicator = new CardDuplicator(apduChannel);
```

Once the instance has been created, depending on the role and state the client must perform a specific action every time a new card is presented. The CardDuplicator keeps track of the action performed on any card, so if the user presents the same card twice an `IllegalStateException` exception is thrown.

To start duplication on a card, for example, you might do

```java
// Client count is the amount of devices contributing to forming the entire key. This means 1 + the number of clients
// which will be adding entropy (the untrusted clients)
cardDuplicator.startDuplication(clientCount);
```

On untrusted clients, to add entropy, you do

```java
cardDuplicator.addEntropy();
```

When the full key has been stored on all cards, you then call the following method on the source card on a trusted client

```java
byte[] exportedKey = cardDuplicator.exportKey();
```

whereas, from the same client, you invoke on all target cards the following

```java
// you should then check that the keyUID matches the one of the source card to be sure that the duplication has been
// performed correctly.
byte[] keyUID = cardDuplicator.importKey(exportedKey);
```
