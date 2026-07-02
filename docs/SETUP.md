# Setup Guide — SpeakEasy App

## AI Teacher API Setup

### Step 1: Get a Free API Key

1. Go to **https://api.chatanywhere.tech/v1/oauth/free/render**
2. Login with your **GitHub account** (create one at https://github.com/signup if needed)
3. Click **Authorize** to grant access
4. Your **API Key** (sk-...) will be displayed — copy it

### Step 2: Configure in App

1. Open the app → go to **Profile tab** → tap **Settings**
2. Under **AI Teacher** section:
   - **API Key**: Paste your `sk-...` key
   - **Base URL**: Keep default `https://api.chatanywhere.tech/v1`
   - **Model**: Select `gpt-4o-mini` (free, 200次/日) or `deepseek-v3` (free, 30次/日)
3. Tap **Test Connection** to verify everything works

### Step 3: Start Using

- Go to **AI Teacher tab** → start chatting in English
- The AI will correct your grammar and suggest improvements

## Available Free Models

| Model | Daily Limit | Recommended For |
|-------|------------|-----------------|
| gpt-4o-mini | 200次 | General conversation, grammar check |
| gpt-4.1-mini | 200次 | Longer contexts |
| gpt-5-mini | 5次 | Advanced responses |
| deepseek-v3 | 30次 | Good quality, more free usage |
| deepseek-r1 | 30次 | Reasoning tasks |

## Default Base URL

```
https://api.chatanywhere.tech/v1
```

(This is pre-configured — no change needed unless using a different provider)
