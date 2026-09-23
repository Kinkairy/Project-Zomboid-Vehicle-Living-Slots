# 3.8.12

3.8.12：修复联机兼容问题。 / Fixed multiplayer compatibility issues.

Removes the small-appliance-specific installation completion override. Coffee makers and toasters now use the same shared installation guard and native completion transaction as existing vehicle parts. This avoids invoking the client mechanics UI check on a dedicated server. The package version remains 3.8.12.

Validation: actual B42.20 Lua installation and removal transactions, with host objects mocked and no client mechanics UI; both appliances install, uninstall and reinstall. Existing crafting and adapter regressions pass. These checks do not replace live multiplayer gameplay acceptance.
