# TeaBot - Smart Tea Companion App 🍵

🔐 User Authentication & Navigation

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

    classDef auth fill:#4CAF50,stroke:#388E3C;
    classDef firebase fill:#FF5722,stroke:#E64A19;
    classDef feature fill:#2196F3,stroke:#1976D2;
    classDef ml fill:#9C27B0,stroke:#7B1FA2;

    class A,B auth;
    class C,D,E,J,K,M feature;
    class F,G,H ml;
    class I,L firebase;
```

🔑 Authentication Result Flow
```mermaid
flowchart TD
    A[User Authentication] --> B[Firebase Authentication]
    B --> C[User Access Granted]
    C -->|Success| D[Navigate to Dashboard]
    C -->|Failure| E[Show Error & Retry]

    classDef auth fill:#4CAF50,stroke:#388E3C;
    class A,B,C auth;
```

🧠 AI & Image Processing Flow
```mermaid
flowchart TD
    A[Image Processing] --> B[Image Compression]
    B --> C[TFLite Model Classification]
    C --> D[Tea Type or Disease Identified]
    D --> E[Save to Firestore]
    E --> F[Update User Consumption Stats]
    D --> G[Prompt Chatbot for Disease Info]
    G --> H[Chatbot Provides Symptoms & Curatives]

    classDef processing fill:#9C27B0,stroke:#7B1FA2;
    class A,B,C,D,E,F,G,H processing;
```

📈 Statistics Visualization Flow
```mermaid
flowchart TD
    A[View Statistics] --> B[Retrieve Data from Firestore]
    B --> C[Generate Daily/Weekly Trends]
    C --> D[Render Statistics Charts]
    D --> E[User Analyzes Trends]

    classDef stats fill:#2196F3,stroke:#1976D2;
    class A,B,C,D,E stats;
```

👤 User Profile Flow
```mermaid
flowchart TD
    A[User Profile Management] --> B[Edit Profile]
    B --> C[Update Firestore Data]
    A --> D[View Profile Information]
    A --> E[Logout]
    E --> F[Revoke Authentication & Navigate to Login]

    classDef profile fill:#FF5722,stroke:#E64A19;
    class A,B,C,D,E,F profile;
```
