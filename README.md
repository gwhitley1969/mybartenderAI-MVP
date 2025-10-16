# MyBartenderAI MVP

AI-powered bartender app that helps users discover and create cocktails based on their preferences and available ingredients.

## 🚀 Current Status: MIGRATION IN PROGRESS ⚠️

- **Backend**: Migrating to Azure Functions v4 (see [DEPLOYMENT_STATUS.md](docs/DEPLOYMENT_STATUS.md))
- **Database**: PostgreSQL configured and ready
- **API**: Functions not loading on Flex Consumption plan
- **Mobile**: Flutter app ready to consume snapshots

## 📁 Project Structure

```
mybartenderAI-MVP/
├── apps/
│   └── backend/          # Azure Functions (Node.js/TypeScript)
├── mobile/
│   └── app/             # Flutter mobile application
├── docs/                # Architecture and documentation
├── prompts/             # AI system prompts
└── spec/                # API specifications
```

## 🏗️ Architecture

- **Backend**: Azure Functions v3 (Node.js 20, Windows Consumption Plan)
- **Database**: PostgreSQL (Azure Database for PostgreSQL)
- **Storage**: Azure Blob Storage for snapshot files
- **Mobile**: Flutter with local SQLite for offline access
- **AI**: OpenAI GPT-4.1 for cocktail recommendations

## 🔧 Quick Start

### Backend
```bash
cd apps/backend
npm install
npm run build
# Deploy using Azure CLI (see DEPLOYMENT_STATUS.md)
```

### Mobile
```bash
cd mobile/app
flutter pub get
flutter run
```

### Smoke Test
```powershell
.\smoke-check.ps1 -ResourceGroup rg-mba-prod -FunctionApp func-mba-fresh
```

## 📚 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Deployment Status](apps/backend/DEPLOYMENT_STATUS.md)
- [API Specification](spec/openapi.yaml)
- [Development Plan](docs/PLAN.md)

## 🎯 Key Features

- **Offline First**: Complete cocktail database available offline
- **AI Recommendations**: Personalized suggestions based on inventory
- **Tiered Access**: Free, Premium, and Pro subscription levels
- **Privacy Focused**: No PII stored for free tier users

## 🔮 Roadmap

1. ✅ Core backend infrastructure
2. ✅ Database synchronization 
3. ✅ Snapshot generation and delivery
4. 🚧 Azure Front Door for image CDN
5. 📱 Mobile app integration
6. 🤖 AI recommendation engine
7. 🎙️ Voice interaction features
8. 📸 Vision AI for bottle recognition

## 🤝 Contributing

This is a private MVP project. For questions or access, please contact the project owner.

## 📄 License

Proprietary - All rights reserved