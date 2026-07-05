# Release Process

1. Update `CHANGELOG.md`.
2. Run:

   ```bash
   swift build -c release
   scripts/build_app.sh
   ```

3. Verify the app launches.
4. Sign and notarize for public distribution.
5. Create a GitHub release with the app bundle or packaged DMG.

Current local builds are ad-hoc signed for development use.
