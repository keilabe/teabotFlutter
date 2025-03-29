# TeaBot - Smart Tea Companion App 🍵

```mermaid
flowchart TD
    A[User Login/Signup] --> B[Firebase Auth]
    B --> C[Dashboard]
    C --> D[Take Tea Photo]
    C --> E[Upload from Gallery]
    D --> F[Image Processing & Compression]
    E --> F
    F --> G[TFLite Model Classification]
    G --> H[Tea Type Detected]
    H --> I[Save to Firestore]
    I --> J[Update Consumption Stats]
    J --> C
    C --> K[View Statistics Charts]
    K --> L[Daily/Weekly Trends]
    C --> M[User Profile]
    M --> N[Edit Profile]
    M --> O[Logout]
    
    %% Style definitions
    classDef auth fill:#4CAF50,stroke:#388E3C;
    classDef firebase fill:#FF5722,stroke:#E64A19;
    classDef feature fill:#2196F3,stroke:#1976D2;
    classDef ml fill:#9C27B0,stroke:#7B1FA2;
    
    %% Apply styles
    class A,B auth;
    class C,D,E,J,K,M feature;
    class F,G,H ml;
    class I,L firebase;
