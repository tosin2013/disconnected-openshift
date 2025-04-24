# OpenShift AI

If you're interested in using OpenShift AI, you'll find that you need to mirror some images that are not included with the ones listed in the Operator Bundle manifest list.  This is because some of the component's lifecycles are separate from that of the OpenShift AI Operator.

So the official documentation for OpenShift AI in a disconnected network are here: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.19/html/installing_and_uninstalling_openshift_ai_self-managed_in_a_disconnected_environment/deploying-openshift-ai-in-a-disconnected-environment_install#mirroring-images-to-a-private-registry-for-a-disconnected-installation_install

And you'll soon find in reading it that there's a repo that has a list of images, an a Markdown doc, like this one - that need to be mirrored depending on the version you're using and when: https://github.com/red-hat-data-services/rhoai-disconnected-install-helper/

So you need to load up that Markdown doc, grab the list of images, mirror them, yada yada.

Or - you could just use the included [Ansible EDA pipeline to automatically mirror images](./deploy-aap-on-openshift.md#openshift-and-eda-integration) like that when they start to go into a CrashloopBackOff/ImagePullErr state.
