---
id: apdu_overview
title: Overview
---

# Overview

This document describes all APDUs part of the Keycard APDU protocol. Any implementation must fully implement this specification except for items explicitly marked as optional or conditional. The Keycard applet is a full implementation of this specification. The Java SDK provides both low-level methods to send each of the APDUs described here as well as convenience methods and classes to simplify integration.

## Version

This documentation is at version 2.0. In this version of the protocol there are no optional or conditional items
 
## Conventions
* When a command has a precondition clause and these are not met the Status Word 0x6985 is returned. 
* All tagged data structures are encoded in the [BER-TLV format](http://www.cardwerk.com/smartcards/smartcard_standard_ISO7816-4_annex-d.aspx).
