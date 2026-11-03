# VM tool updates

`vm/mise.toml` declares version requests. `vm/mise.lock` records exact versions,
Linux x64 downloads, and checksums. Image builds install these locked versions.

## Weekly updates

The **Update mise lockfiles** workflow runs each Monday at 09:00 UTC. It also
supports manual runs from the Actions tab.

The workflow uses the mise version pinned in `Dockerfile`. It updates all
VM tools together, checks that the locked tools install on Linux, and opens
one draft PR from `automation/mise-lockfiles`. It does not update the root
`mise.toml` task tools.

Enable **Allow GitHub Actions to create and approve pull requests** under
**Settings → Actions → General → Workflow permissions**. The workflow uses
`GITHUB_TOKEN`; no extra token is needed.

Mark the PR **Ready for review** to start the image build. Automated PR
creation does not trigger that build. Later automated updates return the PR
to draft, so mark it ready again to check the new versions. Merge only after
the build passes.

Merged updates apply to new images. Running VMs are unchanged.

## Manual updates

Use the mise version pinned in `Dockerfile`, then run:

```sh
mise -C vm lock --upgrade --bump --platform linux-x64
```

Review `vm/mise.lock` before merging. The native tools do not need
npm or Python dependency sidecars.
