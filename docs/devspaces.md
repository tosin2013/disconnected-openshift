# DevSpaces

To use DevSpaces in a disconnected environment isn't too bad - really it's the same workflow as using it in production since you'll often have images for DevFiles that you curate and a Plugin Repository that you manage to keep out random plugins that some "Ken guy" made that may - or may not - have a Bitcoin miner in them.  *Looks like 100% developer productivity gauged by workspace compute consumption though!*

## Plugin Registry

Even though DevSpaces is "based on VSCode" - since it's not VSCode, it doesn't have access to the Microsoft managed VSCode Extension Registry.

This is where open-vsx.org comes in - it's the community driven open source alternative that has many of the same extensions.

You can craft some configuration and a container that can provide your users a Plugin Registry of vetted and approved extensions.  This configuration is once again, JSON-based which is not the easiest to curate.

Thankfully I have some helpers around how to make it easy to maintain a list of plugins as YAML, generate the needed JSON by querying the open-vsx.org API, and build the container needed: https://github.com/kenmoini/che-plugin-registry/

1. Fork & Clone
2. Modify `mirror.yml` to suit your needs - use https://open-vsx.org/ as a source for plugin names
3. Optionally run `python3 generate-mirror-json.py [-o my-file.json]` to test
4. Modify `generate.sh` to suit your needs
5. Run `./generate.sh` to do the full generate of an image and to push it to your remote registry.

With that image built, you'd configure your CheCluster CR to point to it:

```yaml
---
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
spec:
  components:
    pluginRegistry:
      deployment:
        containers:
          - image: disconn-harbor.d70.kemo.labs/quay-ptc/kenmoini/pluginregistry-rhel9:3.18
```

## Custom Default DevFiles

Running a DevFile Registry seems to be falling out of fashion in favor of using ConfigMaps with configuration pointing to the needed resources - a bit lighter on the compute, easier on the workflows, and more GitOps-y.

Say you have a DevFile Stack defined like the one here: https://github.com/kenmoini/devfile-registry/tree/main/stacks/kemo-armillary

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kemo-armillary
  namespace: devspaces
  labels:
    # These labels are important
    app.kubernetes.io/part-of: che.eclipse.org
    app.kubernetes.io/component: getting-started-samples
data:
  # The Data is extracted from the devfile definitions in the stack.
  kemo-armillary.json: |
    [
      {
        "displayName": "Kemo Armillary",
        "description": "v1.0.1 - Complete Armillary development environment",
        "tags": [
          "Go",
          "NodeJS",
          "Node",
          "Armillary",
          "Kemo Ventures"
        ],
        "url": "https://github.com/kenmoini/devfile-registry/stacks/kemo-armillary/1.0.1/",
        "icon": {
          "base64data": "PD94MuchLongStringwowwwo=",
          "mediatype": "image/svg+xml"
        }
      },
      {
        "displayName": "Kemo Armillary",
        "description": "v1.0.0 - Complete Armillary development environment",
        "tags": [
          "Go"
        ],
        "url": "https://github.com/kenmoini/devfile-registry/stacks/kemo-armillary/1.0.0/",
        "icon": {
          "base64data": "PD94MuchLongStringwowwwo=",
          "mediatype": "image/svg+xml"
        }
      }
    ]

```

> You can also use this script to build the ConfigMaps for your DevFile{ Stacks}: https://github.com/kenmoini/devfile-registry/blob/main/cm-builder.sh

## DevFile Images

So the DevFile example linked above uses the `registry.access.redhat.com/ubi9/go-toolset:1.21.9-1.1714671022` image as a base image.  In a disconnected environment that image source would need to be adjusted - and you may even have a need to bake your own (common).
