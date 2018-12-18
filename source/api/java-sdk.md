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
```

After the applet is selected, you can start working with it. At this point, we need to know a few concepts.

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

