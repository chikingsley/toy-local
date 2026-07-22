const {
  PBXBuildFile,
  PBXNativeTarget,
  XCRemoteSwiftPackageReference,
  XCSwiftPackageProductDependency,
} = require("@bacons/xcode");
const {
  withXcodeProjectBeta,
} = require("@bacons/apple-targets/build/with-bacons-xcode");

const packageURL = "https://github.com/pytorch/executorch.git";
// Head of the swiftpm-1.4.0.20260721 snapshot branch, pinned by commit so a
// pruned or force-pushed nightly branch cannot break future builds.
const packageRevision = "d52bb2f8e280079c80430b05778bbb7ed404f8ad";
const keyboardTargetName = "TimberVoxKeyboard";
const packageProducts = ["executorch", "backend_xnnpack", "kernels_optimized"];

module.exports = function withExecuTorchKeyboard(config) {
  return withXcodeProjectBeta(config, (projectConfig) => {
    const project = projectConfig.modResults;
    const keyboardTarget = project.rootObject.props.targets.find(
      (target) =>
        PBXNativeTarget.is(target) && target.props.name === keyboardTargetName,
    );
    if (!keyboardTarget) {
      throw new Error("Unable to locate the TimberVox keyboard Xcode target.");
    }

    project.rootObject.props.packageReferences ??= [];
    let packageReference = project.rootObject.props.packageReferences.find(
      (reference) => reference.props.repositoryURL === packageURL,
    );
    if (!packageReference) {
      packageReference = XCRemoteSwiftPackageReference.create(project, {
        repositoryURL: packageURL,
        requirement: {
          kind: "revision",
          revision: packageRevision,
        },
      });
      project.rootObject.props.packageReferences.push(packageReference);
    } else {
      packageReference.props.requirement = {
        kind: "revision",
        revision: packageRevision,
      };
    }

    keyboardTarget.props.packageProductDependencies ??= [];
    const frameworksPhase = keyboardTarget.getFrameworksBuildPhase();
    for (const productName of packageProducts) {
      let productDependency =
        keyboardTarget.props.packageProductDependencies.find(
          (dependency) =>
            dependency.props.package === packageReference &&
            dependency.props.productName === productName,
        );
      if (!productDependency) {
        productDependency = XCSwiftPackageProductDependency.create(project, {
          package: packageReference,
          productName,
        });
        keyboardTarget.props.packageProductDependencies.push(productDependency);
      }
      if (
        !frameworksPhase.props.files.some(
          (buildFile) => buildFile.props.productRef === productDependency,
        )
      ) {
        frameworksPhase.props.files.push(
          PBXBuildFile.create(project, { productRef: productDependency }),
        );
      }
    }

    keyboardTarget.setBuildSetting("OTHER_LDFLAGS", [
      "$(inherited)",
      "-all_load",
    ]);
    keyboardTarget.setBuildSetting(
      "SWIFT_OBJC_BRIDGING_HEADER",
      "$(SRCROOT)/../targets/keyboard/TimberVoxKeyboard-Bridging-Header.h",
    );
    return projectConfig;
  });
};
