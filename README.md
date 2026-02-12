# Simon AI Coach

> Minimalist AI coaching in your pocket — Build systems that stick

[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Go](https://img.shields.io/badge/Go-1.24-00ADD8.svg)](https://golang.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🎯 Overview

Simon AI Coach is a minimalist mobile application that brings personalized AI coaching to your pocket. Built for productivity enthusiasts who love great design and building systems, it enables users to browse, create, and share AI coaches, add personal context and values, and start chatting immediately — no complex setup required.

**Built for RevenueCat Shipyard 2026 Creator Contest** — Simon (Better Creating) Brief

## ✨ Key Features

### 🤖 AI Coach Library
- **Browse Curated Coaches**: Explore pre-built coaches for focus, planning, creativity, decision-making, wellness, and more
- **Create Custom Coaches**: Design your own AI coaches with personalized avatars, specialties, and coaching styles
- **Save Favorites**: Build your personal coach library with one-tap saving
- **Smart Filtering**: Filter by specialty, style, or saved coaches

### 💬 Multi-Modal Chat Experience
- **Text Chat**: Natural conversation with streaming responses
- **Voice Input**: Record voice messages for hands-free coaching
- **Document Upload**: Share documents for context-aware coaching
- **Voice-Over Responses**: Coaches can respond with natural speech via ElevenLabs TTS
- **Real-Time Streaming**: See responses as they're generated

### ⚡ Moments — Quick Actions
- **Quick Templates**: Pre-built prompts for common coaching needs
- **Direct Chat**: Ask anything and get routed to the most appropriate coach
- **Upcoming Events**: View calendar events, reminders, and notifications
- **Multi-Modal Input**: Text, voice, photos, and documents

### 🛠️ Intelligent Tools
Coaches can take action on your behalf with 9 powerful tools:

**Client Tools** (iOS Integration):
- 📅 **Calendar Events**: Schedule meetings and time blocks
- ⏰ **Reminders**: Create task reminders with due dates
- 🔔 **Notifications**: Schedule push notifications for check-ins
- 📤 **Share Export**: Export plans and reviews as PDF/Markdown

**Server Tools** (Backend):
- 🧠 **Memory**: Save and recall your preferences, goals, and commitments
- 📋 **Plans**: Create structured plans with milestones and actions
- 🔄 **Plan Updates**: Mark actions complete and track progress
- 📆 **Check-ins**: Schedule recurring coaching sessions
- 🔍 **Web Search**: Access current information when needed

### 📚 Library & History
- **Past Conversations**: Browse all coaching sessions
- **Plans & Actions**: View and manage your plans
- **Events**: Track calendar events, reminders, and notifications
- **Search**: Find specific conversations or insights

### 🎨 Deep Personalization
- **Themes**: Light, Dark, or System (follows device)
- **Accent Colors**: 6 beautiful colors (Indigo, Teal, Mint, Orange, Rose, Purple)
- **Font Styles**: System, Rounded, or Serif
- **Text Sizes**: 4 sizes (Small, Medium, Large, X-Large)
- **Cloud Sync**: All preferences synced via Firebase across devices
- **Real-Time Preview**: See changes instantly

### 💎 Premium Features (RevenueCat)
- **Free Tier**: 3 messages per session with any coach
- **Pro Subscription**: Unlimited messages, publish custom coaches, advanced features
- **Flexible Plans**: Weekly ($9.99), Monthly ($29.99), Yearly ($79.99)
- **Restore Purchases**: Seamless cross-device subscription sync

## 🏗️ Architecture

### Tech Stack

**iOS Client** (Native Swift):
- SwiftUI for modern, declarative UI
- AVFoundation for audio recording/playback
- Firebase SDK (Auth, Firestore, Storage)
- RevenueCat SDK for subscriptions
- Server-Sent Events (SSE) for real-time streaming

**Backend** (Go):
- Gin web framework for HTTP routing
- Google Cloud Firestore for database
- Firebase Admin SDK for authentication
- Vertex AI Gemini 3 Flash for LLM
- ElevenLabs API for text-to-speech
- Server-Sent Events for streaming responses

**Infrastructure**:
- Firebase Authentication (Google Sign-In, Apple Sign-In)
- Cloud Firestore (NoSQL database with real-time sync)
- Firebase Storage (file uploads)
- Google Cloud Run (backend deployment)
- Vertex AI (Gemini models)
- Firebase App Check (security)

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS Client (Swift)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   Home   │  │   Chat   │  │ Moments  │  │ Library  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │              │          │
│       └─────────────┴──────────────┴──────────────┘          │
│                          │                                   │
│                    ┌─────▼─────┐                            │
│                    │ API Client │                            │
│                    └─────┬─────┘                            │
└──────────────────────────┼──────────────────────────────────┘
                           │ HTTPS + SSE
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Go Backend (Cloud Run)                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              HTTP Handlers (Gin)                      │  │
│  │  • Chat Stream  • Voice Stream  • Coach CRUD         │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                     │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │           Orchestration Pipeline                      │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │  │
│  │  │  Router  │→ │  Coach   │→ │ Planner  │          │  │
│  │  │  Agent   │  │  Agent   │  │  Agent   │          │  │
│  │  └──────────┘  └──────────┘  └──────────┘          │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
┌───────▼────────┐  ┌──────▼──────┐  ┌───────▼────────┐
│   Firestore    │  │  Vertex AI  │  │  ElevenLabs    │
│   (Database)   │  │  (Gemini)   │  │     (TTS)      │
└────────────────┘  └─────────────┘  └────────────────┘
```

## 🚀 Getting Started

### Prerequisites

- **iOS Development**:
  - Xcode 15.0+
  - iOS 15.0+ device or simulator
  - Apple Developer account (for testing)

- **Backend Development**:
  - Go 1.24+
  - Google Cloud account
  - Firebase project
  - ElevenLabs API key

### Installation

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/simon-ai-coach.git
cd simon-ai-coach
```

#### 2. Backend Setup

```bash
cd backend

# Install dependencies
go mod download

# Set environment variables
cp .env.example .env
# Edit .env with your credentials:
# - GOOGLE_CLOUD_PROJECT
# - ELEVENLABS_API_KEY
# - FIREBASE_PROJECT_ID

# Run locally
./run-local.sh

# Or deploy to Cloud Run
./deploy.sh
```

#### 3. iOS Setup

```bash
cd Simon

# Install dependencies (if using CocoaPods)
pod install

# Open in Xcode
open Simon.xcodeproj

# Add GoogleService-Info.plist from Firebase Console
# Update RevenueCat API key in SimonApp.swift

# Build and run
```

#### 4. Firebase Configuration

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Authentication (Google Sign-In)
3. Create Firestore database
4. Enable Firebase Storage
5. Download `GoogleService-Info.plist` and add to iOS project
6. Set up Firestore security rules (see `firebase/firestore.rules`)

#### 5. RevenueCat Setup

1. Create account at [revenuecat.com](https://www.revenuecat.com)
2. Create iOS app and products
3. Configure offerings and entitlements
4. Update API key in `SimonApp.swift`

## 📱 Usage

### Creating Your First Coach

1. **Open the app** and sign in with Google
2. **Tap the "+" button** in the Home tab
3. **Fill in coach details**:
   - Name and promise
   - Select specialty (Focus, Planning, Creativity, etc.)
   - Choose coaching style (Direct, Warm, Socratic)
   - Adjust tone and verbosity
4. **Generate avatar** with AI (optional)
5. **Tap "Create Coach"**
6. **Start chatting** immediately

### Starting a Coaching Session

1. **Browse coaches** in the Home tab
2. **Tap a coach card** to view details
3. **Tap "Start Session"**
4. **Chat naturally** — the coach will:
   - Remember your context
   - Offer to create plans
   - Schedule reminders
   - Provide structured guidance

### Using Moments

1. **Tap the Moments tab**
2. **Choose input method**:
   - Type a message
   - Record voice
   - Select a quick template
3. **Add attachments** (photos, documents)
4. **Enable voice-over** for spoken responses
5. **Send** — you'll be routed to the best coach

### Managing Subscriptions

1. **Tap Settings tab**
2. **View subscription status**
3. **Tap "Upgrade to Pro"** for unlimited access
4. **Choose plan**: Weekly, Monthly, or Yearly
5. **Complete purchase** via App Store

## 🎨 Design Philosophy

Simon AI Coach follows a minimalist design philosophy:

- **Clean Interface**: No clutter, just what you need
- **Fast Interactions**: Streaming responses, instant feedback
- **Thoughtful Animations**: Subtle, purposeful motion
- **Accessibility First**: VoiceOver support, dynamic type
- **Dark Mode**: Beautiful in light and dark themes

## 🧪 Testing

### Backend Tests
```bash
cd backend
go test ./...
```

### iOS Tests
```bash
cd Simon
xcodebuild test -scheme Simon -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Manual Testing Checklist

- [ ] Sign in with Google
- [ ] Browse and filter coaches
- [ ] Create custom coach
- [ ] Start chat session
- [ ] Send text message
- [ ] Record voice message
- [ ] Upload document
- [ ] Enable voice-over
- [ ] Use quick template
- [ ] Create plan via coach
- [ ] Schedule reminder
- [ ] View library
- [ ] Hit message limit
- [ ] Purchase subscription
- [ ] Restore purchases

## 📊 Performance

- **Response Latency**: ~200-500ms for streaming start
- **Voice-Over Latency**: ~200-500ms for audio playback
- **Message Limit**: 3 free messages per session
- **Subscription Sync**: Real-time via RevenueCat

## 🔒 Security & Privacy

- **Authentication**: Firebase Auth with Google Sign-In
- **Data Encryption**: TLS 1.3 for all network traffic
- **Privacy Filters**: Automatic PII detection and redaction
- **User Control**: Export, view, and delete your data
- **No Tracking**: No third-party analytics or ads

## 🤝 Contributing

This project was built for the RevenueCat Shipyard 2026 Creator Contest. Contributions are welcome after the contest period.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Simon (Better Creating)** for the inspiring brief
- **RevenueCat** for the Shipyard Creator Contest
- **Google Cloud** for Vertex AI and Firebase
- **ElevenLabs** for natural text-to-speech
- **The Swift and Go communities** for excellent tools and libraries

## 📞 Contact

- **Developer**: [Your Name]
- **Email**: [your.email@example.com]
- **Twitter**: [@yourhandle]
- **Project Link**: [https://github.com/yourusername/simon-ai-coach](https://github.com/yourusername/simon-ai-coach)

## 🏆 Built for Shipyard 2026

This app was created for the RevenueCat Shipyard: Creator Contest, building a real, monetizable MVP for Simon (Better Creating) and his audience of productivity enthusiasts.

---

**Made with ❤️ for the Better Creating community**
