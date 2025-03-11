# Introduction to Auth

Authentication (authn) and authorization (authz) are two important concepts in security. Authentication is the process of verifying the identity of a user or system, while authorization is the process of granting or denying access to resources based on the user's identity and permissions.

Phoenix comes with built-in support for both. Generally speaking, developers use the `mix phx.gen.auth` generator to scaffold their authn and authz. Third-party libraries such as [Ueberauth](https://github.com/ueberauth/ueberauth) can be used either as complementary systems or by itself.

Overall we have the following guides:

  * [mix phx.gen.auth](mix_phx_gen_auth.md) - An introduction to the `mix phx.gen.auth` generator and its security considerations.

  * [Scopes](scopes.md) - Scopes are the mechanism Phoenix v1.8 introduced to manage access to resources based on the user's identity and permissions.

  * [API Authentication](api_authentication.md) - An additional guide that shows how to expand `mix phx.gen.auth` code to support token-based API authentication.
