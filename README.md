# 🛡️ AntiVPN plugin for AMX Mod X (GoldSrc Servers)

An **Anti-VPN / Anti-Proxy plugin** for GoldSrc servers running **AMX Mod X**, featuring advanced detection capabilities — even for clients who are _pseudo-connected_ to the game server.

---

## ⚙️ Requirements

Make sure your server meets the following minimum versions:

- **AMX Mod X** `1.9.0-5271+`
- **ReHLDS** `v3.13.0.788+`
- **ReGameDLL** `v5.26.0.668+`
- **ReAPI** `v5.24.0.300+`
- **AmxxEasyHTTP** `v1.4.0+`

> 📦 The plugin utilizes [ProxyCheck.io](https://proxycheck.io/) for proxy/VPN API detection.

---

## 🔧 CVARs (Configuration Variables)

| CVAR                      | Description                                                                        |
|---------------------------|------------------------------------------------------------------------------------|
| `vpn_punish_type`         | Action to take against VPN users. <br>**Valid values**: `none`, `kick`, `ban` <br>_Note: `none` only logs the detection, still queries the API._ |
| `vpn_ban_time`            | Duration (in minutes) to ban VPN users (if ban is selected).                      |
| `vpn_contact`             | Contact info (URL or Discord) shown to kicked players.                            |
| `vpn_apikey_cvar`         | Your API key from [ProxyCheck.io](https://proxycheck.io/dashboard/).              |
| `vpn_reload_file_access` | Access flag required to reload the VPN configuration file.                         |

---

## 🛠️ Commands

| Command                         | Description                                                                      |
|----------------------------------|----------------------------------------------------------------------------------|
| `amx_remove_vpn <IP>`           | Removes cached VPN/proxy status for the specified IP from local storage.        |
| `amx_reload_whitelist_file`     | Reloads the `VPNConfiguration.ini` file.                                        |

---

## 🌐 Servers Using This Plugin

View active servers running this plugin on [TheGamesTracker.com](https://thegamestracker.com/servers/none?by=server_variable&query=anti_vpn)

---

## 🙏 Credits

- 💻 [**Next21Team**](https://github.com/Next21Team) — for the [AmxxEasyHTTP](https://github.com/Next21Team/AmxxEasyHttp) module.
- 🔎 [**ProxyCheck.io**](https://proxycheck.io/) — for the reliable proxy/VPN checking API.
