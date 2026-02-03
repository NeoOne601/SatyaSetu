# **Satya Setu: Master Implementation Blueprint**

**"The Sovereign Spatial Marketplace for India"**

## **1\. Executive Vision: Sovereign Commerce**

**The Concept:**

Satya Setu transforms the mobile camera into a **Spatial** Browser that indexes physical reality. It replaces the centralized "search engine" model with a decentralized, verifiable **"Web** of **Trust"** for physical objects, empowering users with data sovereignty and businesses with a direct, rent-free connection to customers.

**The Pivot:**

We are evolving from a passive "AR Viewer" into an active **"Contextual Commerce Engine."** Users select objects in the real world to access a decentralized marketplace of trusted options, paid via sovereign rails (UPI/e-Rupee), and verified by a community consensus protocol.

**Core Principles:**

1. **Sovereignty:** User keys (Ed25519) never leave the device. Identity is self-sovereign (DID).  
2. **Privacy:** Intelligence happens at the edge. Visual data is processed locally.  
3. **Compliance:** Full adherence to Indian Data Sovereignty laws, utilizing India Stack (UPI, GSTIN) for all financial and identity verification.

## **2\. System Architecture: The "See-Think-Act" Loop**

The system operates as a **Hybrid-Native Node**, integrating three distinct ecosystems.

### **A. Perception Layer (The Eyes)**

* **Role:** Real-time object detection and AR rendering.  
* **Technology:** Flutter (UI) \+ Python (Backend).  
* **Implementation:**  
  * **Mobile:** VisionService captures video frames and tunnels them to a local server to save battery.  
  * **Server:** apple\_vision\_server.py runs CoreML/YOLO models to detect objects (e.g., "Sneaker", "Router") and returns bounding boxes.  
* **Innovation:** **"Reactive Event Bus"** decouples vision from commerce. The camera continues scanning (60fps) while the commerce engine queries data asynchronously.

### **B. Cognition Layer (The Brain)**

* **Role:** Mapping objects to context and actions.  
* **Technology:** IntentEngine (Dart) \+ CommerceService (Dart).  
* **Implementation:**  
  * **Intent:** Determines *what* an object is.  
  * **Affordance:** Generates buttons like "Connect," "Buy," or "Verify."  
  * **Search:** Queries the local and global indexes for product matches based on visual embeddings.

### **C. Memory Layer (The Cortex)**

* **Role:** Persistent storage of the "Trust Graph."  
* **Technology:** **SQLite** (Local) \+ **PostgreSQL/Redis** (Cloud).  
* **Implementation:**  
  * **Local Cortex:** Stores private interaction history ("I verified this yesterday").  
  * **Global Indexer:** Stores public, signed events from the Nostr network ("10,000 people verify this").

### **D. Sovereignty Layer (The Vault)**

* **Role:** Cryptographic security and signing.  
* **Technology:** **Rust** (rust\_core).  
* **Implementation:**  
  * **Enclave:** Securely stores private keys.  
  * **Signer:** Signs every interaction ("I saw this," "I bought this") as a Nostr event.  
  * **Bridge:** Linked statically to the mobile app via FFI for native performance.

## **3\. Data Architecture & Database Design**

To ensure **High Availability** (Offline First) and **Eventual Consistency** (Decentralized Sync), we use a "Twin-Cortex" strategy.

### **3.1. Local Cortex (Mobile Device \- SQLite)**

* **File:** satya\_cortex.db  
* **Role:** Private memory and offline cache.

erDiagram  
    ENTITIES ||--o{ INTERACTIONS : "history"  
    VENDORS ||--o{ PRODUCTS\_CACHE : "offers"

    ENTITIES {  
        string id PK "Hash(Label+Geohash)"  
        string label "Object Name"  
        real trust\_score "Local Trust (0.0-1.0)"  
        string geohash "Location Index"  
        int last\_seen  
    }

    INTERACTIONS {  
        int id PK  
        string entity\_id FK  
        string action\_type "RATE, BUY"  
        int rating  
        string signature "Crypto Proof"  
        int timestamp  
    }

    PRODUCTS\_CACHE {  
        string product\_id PK  
        string entity\_label FK  
        string vendor\_did  
        int price\_inr  
        string image\_url  
        real cached\_rank  
        int expires\_at  
    }

### **3.2. Global Indexer (Central Infrastructure \- PostgreSQL)**

* **Role:** The "Google" of the system. Ingests millions of Nostr events.  
* **Tech:** PostgreSQL \+ PostGIS (Maps) \+ pgvector (AI Search).

erDiagram  
    GLOBAL\_EVENTS {  
        string event\_id PK  
        string pubkey "Author DID"  
        int kind "1040=Ad, 1985=Review"  
        jsonb content  
        geometry location "PostGIS Point"  
        string geohash  
    }  
    VECTORS {  
        string event\_id FK  
        vector embedding "768-dim Visual Vector"  
    }

### **3.3. Speed Strategy**

* **Geohashing:** O(1) spatial lookups.  
* **Redis Cache:** Stores pre-calculated "Trust Tiles" for popular regions (e.g., Connaught Place, Delhi).

## **4\. UI/UX Implementation: The "Sovereign Interface"**

**Goal:** Seamless transition from "Seeing" to "Buying" without leaving the visual context.

### **4.1. The "Reactive Drawer" (Commerce Discovery)**

Instead of a split screen, we use a DraggableScrollableSheet overlay.

* **State 0 (Scanner):** Full-screen camera with AR overlays (MorphicTile).  
* **Interaction:** User taps a "Sneaker" tile.  
* **State 1 (The Peek \- 40%):**  
  * **Action:** Camera **freezes** on the current frame (battery/focus lock).  
  * **UI:** Drawer slides up.  
  * **Content:** Object Title, Trust Score Badge ("85% Safe"), and "Quick Actions" (Verify, Report).  
  * **Loader:** "Searching Decentralized Graph..."  
* **State 2 (The Market \- 90%):**  
  * **Interaction:** User drags drawer up.  
  * **UI:** Full marketplace list view. Camera dimmed in background.  
  * **Tabs:**  
    1. **Verified:** Trusted vendors (Green/Gold borders).  
    2. **Global:** Unfiltered results.  
    3. **Bounties:** New products seeking verification.

### **4.2. Visual Design System**

* **Trust Colors:**  
  * **Neon Teal (\#00FFC8):** Trusted/Safe.  
  * **Gold (\#FFD700):** Promoted/Sponsored.  
  * **Red (\#FF0055):** Malicious/Untrusted.  
  * **Blue (\#0088FF):** Bounty Active.  
* **Motion:** Physics-based spring animations for all drawer transitions (60fps).

## **5\. Administration & Governance (The Control Room)**

**Philosophy:** Strict "State Separation." Admin controls the Index and Economy, but **never** user keys.

### **5.1. Microservices Architecture (Kubernetes)**

1. **The Spider:** Ingests events from Nostr Relays \-\> Postgres.  
2. **The Vectorizer:** Computes AI embeddings for visual search \-\> Qdrant.  
3. **The Warden (KYC):** Verifies businesses via **GSTIN / PAN** APIs. Signs "Verified Vendor" credentials.  
4. **The Ad Auctioneer:** Manages bid logic (Bid \* Trust Score).

### **5.2. Sovereign Monetization (India Stack)**

* **Payment Rails:** **UPI** (Intent Flow) and **e-Rupee** (CBDC). No foreign gateways.  
* **Revenue Streams:**  
  * **Vendor Verification:** Recurring fee for "Verified" badge (GST compliant).  
  * **Promoted Signals:** Vendors stake INR to boost signal propagation.  
  * **Bounty Payouts:** Direct Benefit Transfer (DBT) to user UPI handles for verifying new products.

## **6\. Implementation Roadmap**

### **Phase 11: The Cortex (Local Persistence)**

* **Objective:** Give the app a memory.  
* **Tasks:**  
  1. Add sqflite dependencies.  
  2. Implement DatabaseService with the SQLite schema.  
  3. Hook VisionService to query DB on detection.

### **Phase 12: Sovereign Commerce (UI & Logic)**

* **Objective:** Build the marketplace interface.  
* **Tasks:**  
  1. Build SovereignDrawer widget (DraggableScrollableSheet).  
  2. Implement CommerceService with ranking logic (TrustRank).  
  3. Create "Bounty" UI components.

### **Phase 13: The Protocol (Nostr Integration)**

* **Objective:** Connect to the decentralized web.  
* **Tasks:**  
  1. Upgrade rust\_core to expose sign\_event FFI methods.  
  2. Implement Dart WebSocket client for Nostr relays.

### **Phase 14: The Forge (Custom Affordances)**

* **Objective:** User-defined actions.  
* **Tasks:**  
  1. Create Editor UI for custom intents.  
  2. Implement JSON logic for user scripts.

### **Phase 15: Production Hardening**

* **Objective:** Security and Performance.  
* **Tasks:**  
  1. Audit Rust memory safety for keys.  
  2. Profile image buffer usage.  
  3. **Testing:** Full loop integration tests (Camera \-\> DB \-\> UI).

## **7\. Testing Strategy**

* **Unit Tests:** Verify SQLite read/write speeds (\<5ms) and Rust signature validity.  
* **Integration Tests:** Simulate full user flows: "Scan Object \-\> Tap \-\> View Drawer \-\> Verify."  
* **UX Tests:** "The Thumb Test" – ensure one-handed operation is fluid.  
* **Network Tests:** Verify offline fallback behavior (Local DB vs. Cloud Index).

This master