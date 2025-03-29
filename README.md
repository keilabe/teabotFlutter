# TeaBot - Smart Tea Companion App 🍵

A Flutter app that combines AI tea classification, Firebase integration, and consumption tracking with interactive charts.

```mermaid
flowchart TD
    A[User Login/Signup] --> B{{Firebase Auth}}
    B --> C[Dashboard]
    C --> D[Take Tea Photo]
    C --> E[Upload from Gallery]
    D --> F[Image Processing\n& Compression]
    E --> F
    F --> G[TFLite Model\nClassification]
    G --> H{{Tea Type Detected\n(E.g. Green, Black, Herbal)}}
    H --> I[Save to Firestore]
    I --> J[Update Consumption Stats]
    J --> C
    C --> K[View Statistics Charts]
    K --> L[Daily/Weekly Trends\nCaffeine Tracking\nFlavor Preferences]
    C --> M[User Profile]
    M --> N[Edit Profile\nLogout]
    
    style A fill:#4CAF50,stroke:#388E3C
    style B fill:#FF5722,stroke:#E64A19
    style C fill:#2196F3,stroke:#1976D2
    style F fill:#9C27B0,stroke:#7B1FA2
    style G fill:#009688,stroke:#00796B
    style H fill:#FFC107,stroke:#FFA000
    style L fill:#00BCD4,stroke:#0097A7
