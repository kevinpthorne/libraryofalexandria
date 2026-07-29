# Sipcord & Asterisk ConfBridge Setup Guide

This guide explains how to configure and deploy **Sipcord** (SIP-to-Discord Voice Bridge) integrated with the `loa-voip` Asterisk server using `ConfBridge`.

---

## Architecture Overview

```
+----------------+      +-------------------+      +-------------------+      +---------------+
|  VoIP Phone /  | ---> | Asterisk Server   | ---> |  Sipcord Bridge   | ---> | Discord Voice |
| Softphone App  |      | (loa-voip)        |      | (sipcord-bridge)  |      |    Channel    |
+----------------+      +-------------------+      +-------------------+      +---------------+
                            |                                |
                            +----- ConfBridge (Multi-User) --+
```

1. **Asterisk (`loa-voip`)**: Receives calls from internal VoIP phones/clients. Dialing an extension like `6001` places the caller into Asterisk `ConfBridge(6001)` and originates an internal SIP call to Sipcord (`sip:6001@sipcord.voip.svc.cluster.local:5060`).
2. **Sipcord Bridge (`sipcord`)**: Translates SIP audio to Discord voice packets via Serenity/Songbird libraries using the configuration defined in `dialplan.toml`.
3. **Discord Voice Channel**: The Sipcord Discord bot joins the target voice channel and streams two-way audio.

---

## Step 1: Discord Bot Setup

### 1. Create a Discord Application
1. Go to the [Discord Developer Portal](https://discord.com/developers/applications).
2. Click **New Application**, give it a name (e.g., `Sipcord-Bridge`), and accept the Developer Terms.

### 2. Configure the Bot & Copy Token
1. In the left sidebar, click **Bot**.
2. Click **Reset Token** (or **Copy Token**) to obtain your `DISCORD_BOT_TOKEN`. Save this token securely.
3. Scroll down to **Privileged Gateway Intents**:
   - Ensure **Voice State Intent** (if prompted) or default bot permissions are enabled.

### 3. Invite the Bot to Your Discord Server
1. In the left sidebar, click **OAuth2** -> **URL Generator**.
2. Under **Scopes**, select `bot`.
3. Under **Bot Permissions**, select:
   - **View Channels**
   - **Connect**
   - **Speak**
   - **Send Messages** (optional, for text channel fax features)
4. Copy the generated URL at the bottom and open it in your browser to invite the bot to your Discord server (Guild).

---

## Step 2: Retrieve Discord Guild and Channel IDs

1. Open Discord, go to **User Settings** -> **Advanced**, and turn on **Developer Mode**.
2. Right-click your Discord Server (Guild) icon in the sidebar and select **Copy Server ID** (`GUILD_ID`).
3. Right-click the desired Voice Channel and select **Copy Channel ID** (`CHANNEL_ID`).

---

## Step 3: Configure `k-apps` Values

In your cluster values file (or in `apps/k-apps/values.yaml`), update the `sipcord` block:

```yaml
sipcord:
  enabled: true
  discordBotToken: "YOUR_ACTUAL_DISCORD_BOT_TOKEN"
  channels:
    - extension: 6001
      guild: "123456789012345678"     # Replace with your Guild ID
      channel: "987654321012345678"   # Replace with your Voice Channel ID
      name: "General Voice"
    - extension: 6002
      guild: "123456789012345678"
      channel: "111222333444555666"
      name: "Gaming Voice"
```

---

## Step 4: Dialing Instructions

### Option A: Direct Extension Dialing
Dial extension `6001` or `6002` directly from your SIP phone/client:
- Your call will be placed into `ConfBridge(6001)`.
- The Sipcord bot automatically joins the mapped Discord voice channel and bridges two-way audio.

### Option B: Interactive IVR Selection
Dial extension `6000`:
- Asterisk prompts: *"Please enter the 4-digit extension followed by pound."*
- Enter `6001#` to join extension 6001's Discord voice channel.

---

## Step 5: Verification & Debugging

### Check Pod Status
```bash
kubectl get pods -n voip
```
You should see `sipcord-xxx` and `loa-voip-asterisk-xxx` running.

### Inspect Sipcord Logs
```bash
kubectl logs -f -l app=sipcord -n voip
```
Verify that `dialplan.toml` loaded correctly and the Discord bot logged in successfully.

### Check Asterisk Dialplan & ConfBridge Status
```bash
# Exec into Asterisk container
kubectl exec -it deployment/loa-voip-asterisk -n voip -- asterisk -r

# Inside Asterisk CLI:
core show dialplan from-kamailio
confbridge list
```
