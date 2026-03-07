# Deep Linking Showcase Notes

## Local Manual Test Flow
1. Start the app with `npm run dev`.
2. Initiate an LTI launch with message type `LtiDeepLinkingRequest` to `POST /launch`.
3. Confirm the tool renders the deep-linking picker with `Resource 1`, `Resource 2`, and `Resource 3`.
4. Select one resource and confirm the response is an auto-submitting form (`id="deep-linking-form"`) posting `JWT` to the platform deep-link return URL.
5. Repeat step 4 for all three resources.
6. Launch the created placement as `LtiResourceLinkRequest` and confirm the launch page displays the selected deep-linked resource context.

## Automated Validation
- `gleam build`
- `gleam run -m lti_example_tool/database/migrate test.reset`
- `gleam test`

## Known Validation Gap
- `gleam format --check src test` currently fails due pre-existing formatting drift in `src/lti_example_tool/db_provider.gleam`.
