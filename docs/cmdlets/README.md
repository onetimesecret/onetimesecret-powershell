# Cmdlet reference

Generated from the module's comment-based help by `./build.ps1 -Task Docs`
(platyPS). Do not edit these files by hand; change the help in
`src/OnetimeSecret/Public/*.ps1` and regenerate.

| Cmdlet | Synopsis |
| ------ | -------- |
| [Connect-OtsAccount](Connect-OtsAccount.md) | Establishes the connection that other OnetimeSecret cmdlets use. |
| [Disconnect-OtsAccount](Disconnect-OtsAccount.md) | Forgets the default connection set by Connect-OtsAccount. |
| [Get-OtsConnection](Get-OtsConnection.md) | Returns the connection the module is currently using. |
| [Get-OtsReceipt](Get-OtsReceipt.md) | Gets receipts: the creator-side record of a secret's state and links. |
| [Set-OtsReceipt](Set-OtsReceipt.md) | Updates a receipt's memo. |
| [Get-OtsSecret](Get-OtsSecret.md) | Gets a secret's metadata without revealing its value. |
| [New-OtsSecret](New-OtsSecret.md) | Creates a one-time secret and returns its receipt, including the share link. |
| [Receive-OtsSecret](Receive-OtsSecret.md) | Reveals a secret's value. This consumes the secret; it cannot be read again. |
| [Remove-OtsSecret](Remove-OtsSecret.md) | Burns a secret before anyone reads it. |
| [Get-OtsSecretStatus](Get-OtsSecretStatus.md) | Checks whether secrets still exist and what state they are in. |
| [Get-OtsStatus](Get-OtsStatus.md) | Reports whether the Onetime Secret service is up. |

See also `Get-Help about_OnetimeSecret`.
