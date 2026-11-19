const handsOff = {
  automerge: true,
  automergeType: 'pr',
  platformAutomerge: true,
  ignoreTests: true,            // remove once flate gates PRs
  minimumReleaseAge: '3 days',
};
const needsMe = {
  automerge: false,
  addLabels: ['review-required']
};

module.exports = {
  $schema: 'https://docs.renovatebot.com/renovate-schema.json',
  extends: [
    'config:recommended',
    ':semanticCommits',
    ':dependencyDashboard'
  ],

  onboarding: false,
  requireConfig: 'optional',

  timezone: 'Europe/Berlin',
  labels: ['dependencies'],
  prHourlyLimit: 10,
  prConcurrentLimit: 20,
  branchConcurrentLimit: 20,
  ignorePaths: ['**/*.sops.yaml', '**/node_modules/**'],

  separateMajorMinor: false,
  separateMinorPatch: false,
  internalChecksFilter: 'strict',

  packageRules: [
    {
      // Works for ANY repo laid out as <root>/<component>/…
      // kubernetes/traefik/common → group "traefik", branch renovate/kubernetes-traefik
      // apps/foo/manifests       → group "foo",      branch renovate/apps-foo
      description: 'One PR per component directory',
      matchFileNames: ['*/*/**'],
      groupName: "{{lookup (split packageFileDir '/') 1}}",
      groupSlug: "{{lookup (split packageFileDir '/') 0}}-{{lookup (split packageFileDir '/') 1}}",
      groupSingleUpdates: true,
    },
    {
      description: 'patch + digests',
      matchUpdateTypes: ['patch', 'digest', 'pinDigest'],
      ...handsOff
    },
    {
      description: 'minor + major',
      matchUpdateTypes: ['minor', 'major'],
      ...needsMe
    },
  ],
};