# VoIP User Enrollment via Keycloak

Because Asterisk is integrated directly with Keycloak's PostgreSQL database using `res_odbc` Realtime, enrolling a user for a VoIP extension is as simple as adding a few custom attributes to their user profile in Keycloak.

## Prerequisites
The user must be enabled in Keycloak (`Enabled: ON`).

## Required Attributes
Log into the Keycloak Admin Console, navigate to the **Users** section, select the user you want to enroll, and go to the **Attributes** tab. 

> [!NOTE]
> **Missing the Attributes tab?** In newer Keycloak versions, the "Attributes" tab is hidden by default due to the new Declarative User Profile system. To bring it back:
> 1. In the left menu, go to **Realm Settings**.
> 2. Click on the **User Profile** tab.
> 3. Find the **Unmanaged Attributes** setting and change it from `Disabled` to `Enabled` (or `Admin can edit`).
> 4. Click **Save**. The Attributes tab will now appear on all user profiles!

You need to add the following two attributes:

### 1. `extension`
This will be the user's phone number / extension (e.g., `1001`, `1002`, `6001`).
* **Key**: `extension`
* **Value**: `<desired_extension_number>`

### 2. `sip_ha256`
Asterisk is configured to use `sha256` authentication to avoid storing plaintext SIP passwords in the database. You must generate a SHA-256 hash of the string `username:realm:password`.

* **username**: The user's `extension`
* **realm**: `asterisk` (the default PJSIP realm)
* **password**: The plaintext password the user will use on their SIP phone.

**How to generate the hash (Linux/macOS):**
Open a terminal and run the following command, replacing the values with your actual extension and desired SIP password:

```bash
# Format: extension:asterisk:password
echo -n "1001:asterisk:SuperSecretPassword123" | sha256sum | awk '{print $1}'
```

Copy the output hash and paste it into Keycloak:
* **Key**: `sip_ha256`
* **Value**: `<the_generated_hash>`

## Optional Attributes

### `sip_enabled`
By default, any Keycloak user with an `extension` and `sip_ha256` attribute is automatically enabled for SIP (assuming their Keycloak account is enabled). 

If you want to temporarily disable their SIP access without deleting their extension or hash, you can add this attribute:
* **Key**: `sip_enabled`
* **Value**: `false`

*(To re-enable, simply remove the attribute or set it to `true`).*

---
## Verification
Once you save the attributes in Keycloak, the database views (`ps_endpoints`, `ps_auths`, `ps_aors`) are automatically populated. You can instantly register a SIP phone (like a desk phone, Zoiper, or Linphone) using the extension and the plaintext password you chose. Asterisk will read the views in real-time and authenticate the user!
