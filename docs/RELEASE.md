# Release Process

1. Update `CHANGELOG.md`.
2. Run local validation:

   ```bash
   scripts/package_release.sh 0.1.0
   ```

3. Verify the app launches.
4. Create and push a version tag:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

5. GitHub Actions packages and uploads:
   - macOS arm64 app zip
   - Windows x64 installer exe
   - SHA256 checksum files

Current local builds are unsigned/ad-hoc signed for development use. Public notarized DMG packaging and signed Windows installers are future release-readiness steps.
