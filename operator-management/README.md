# Operator Management

Installing OpenShift from a mirror is easy - managing the hundreds of Operators for OpenShift is a bit more involved, but hopefully this makes things easier.

Speaking of easy...

## How to Not Do Any of This

If you have a container image registry already deployed, and if it's able to access the Internet and be reached by private networks, then you can likely configure it as a Pull-through or Proxy Cache.  Image registries such as JFrog Artifactory, Harbor, Nexus, etc can function as this sort of image broker.

What this does is make it to where when you request `quay.io/kenmoini/banana-phone` via your private container image registry - say at `harbor.example.com/quay-cache/kenmoini/banana-phone` - the image registry will go pull it down locally to itself, then serve it to the client requesting the image.

This means that any external images can be transparently pulled in without intervention, while also giving you control over what is brought in with the respective policy engines these registries have.

> If you can do this, you should, otherwise you're going to have a lot more work to do.

- [Configure Harbor to work as a Pull-through/Proxy Cache](./pullthrough-proxy-cache-harbor.md)
- [Configure JFrog to work as a Pull-through/Proxy Cache](./pullthrough-proxy-cache-jfrog.md)

---

