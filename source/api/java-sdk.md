---
id: java-sdk
title: Keycard Java SDK
---

## Installation

You can import the SDK in your Gradle or Maven project using [Jitpack.io](https://jitpack.io). If using Gradle, to use
JitPack all you have to do is insert these lines in you ```build.gradle``` file

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

On Android, the NFC connection handling must happen on a thread separate from the UI thread. The SDK provides the class
```NFCCardManager``` to handle this. This an example activity starting the NFC reader and handling the connection to the
card. Refer to the comments in the example for more information.

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

On the desktop we use the javax.smartcardio library. There are several ways to handle connections, the important part is
getting a CardChannel open. Below is an example of how this can be achieved (assumes that a single smartcard reader is
connected).

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

Regardless whether you are on Android or desktop, you should at this point have an implementation of the CardChannel
interface (be it NFCCardChannel or PCSCCardChannel). You can now start working with the card. The first thing to do is
creating a ```KeycardCommandSet``` instance. This class gives access to all of the applet functionality, wrapping the
low-level APDUs in easy to use methods. All other classes in the SDK are helper to format parameters and parse responses
from the card. To create a command set, just do

```java
// cardChannel is our CardChannel instance
KeycardCommandSet cmdSet = new KeycardCommandSet(cardChannel);
```

Modern SmartCards can have several applications installed, so after connection with the card you need to select the
Keycard applet. This is easily done with

```java
// The checkOK method can be called on any APDUResponse object to confirm that the
cmdSet.select().checkOK();
```

While this correctly selects the applet, it discards the card response, which contains information that can be useful
to identify this specific card and its state. For this reason we could rewrite this as

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

After the applet is selected, you can start working with it. Note that the application remains selected until another
applet is explicitly selected, or the card is powered off (for example is removed from the field)

### Initialization

This step is necessary to bring the initial credentials on the Keycard instance. When the card is not initialized, it 
cannot perform any operation. Initialization sets the initial PIN, PUK and pairing password and requires no 
authentication, but still uses a SecureChannel resistant to passive MITM attacks. Once the card is initialized, it
cannot be initialized again (but credentials can be different with a different mechanism with previous authentication).

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

Clients wishing to communicate with the card, need to pair with it first. This allows creating secure channels resistant
not only to passive but also to active MITM attacks. Although pairing allows the card and the client to authenticate
each other, the card does not grant access to any operation with the wallet until the user is authenticated (by verifying
its PIN). To establish the pairing, the client needs to know the pairing password. After it is established, the pairing
info (not the password) must be stored as securely as possible on the client for subsequent sessions. You should
store the pairing information together with the instance UID to simplify handling of multiple cards.

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

After a pairing has been established, a secure channel can be opened. Before opening a secure channel, the card won't
allow sending any command. This guarantees secrecy, integrity and authenticity of the commands. Opening a secure channel
must be performed every time the applet is selected (this means also after a power loss). After opening it, the SDK
handles the secure channel transparently, encrypting and signing all command APDUs and decrypting and verifying the
signature of all responses. To open a secure channel all you need to do is

```java
cmdSet.autoOpenSecureChannel();
```

### Authenticating the user

Most operations with the card (all involving operations with the wallet or credentials) require authenticating the user.
After authentication, the user remains authenticated until the card is powered off or the application is re-selected.

Authentication is performed by verifying the user PIN. Note that this piece of information is sensitive and must be
handled accordingly in the application. PIN verification is done with a single step

```java
// pin is the user PIN as a string of 6 digits
cmdSet.verifyPIN(pin).checkOK();
```

## Creating a wallet

To actually use the Keycard, it needs to have a wallet. This can be achieved in several different ways, which one you
choose depends on your usage scenario. Creating a wallet requires user authentication and is possible even if a wallet
already exists on the card (the new wallet replaces the old one). Use the ```ApplicationInfo.hasMasterKey()``` method
to determine if the card already has a wallet or not. Note that the response of the ```KeycardCommandSet.loadKey``` method
contains the key UID of the created wallet. This UID can be stored to keep track of this specific wallet in the client.
The UID is tied to the key itself (is derived from the public key) so it will change if the wallet on card is replaced.
The key UID is also part of the response of the applet selection command, so the wallet can be identified immediately
upon selection.

### Creating a BIP39 mnemonic phrase

This method is great for interoperability with other wallets. The card can assist in creating the mnemonic phrase, since 
it features a TRNG. Generating the mnemonic itself does not require user authentication (since it does not modify the
card state), but loading the key derived from it does. Example of the entire procedure is below

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

This is the simplest and safest method, because the generated wallet never leaves the card and there is no "paper backup" 
to keep secure. It is possible to create secure backups of the wallet on other Keycards, with a mechanism described in
later chapters. Using the SDK, you simply do

```java
cmdSet.generateKey().checkOK();
```

### Importing an EC keypair

You can import on the keycard any EC keypair on the SECP256k1 curve, with or without the BIP32 extension. If your import 
a key without the BIP32 extension, then key derivation will not work, but you will still be able to use the Keycard for 
signing transactions using the imported key. This scenario can be useful if you are migrating from a wallet not using 
BIP39 passphrases or for wallets following some custom generation rules. It is however generally preferable to use one 
of the methods presented above.

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


