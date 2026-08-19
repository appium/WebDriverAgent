export const PLATFORM_NAME: string = requireEnv('PLATFORM_NAME');
export const PLATFORM_VERSION: string = requireEnv('PLATFORM_VERSION');
export const DEVICE_NAME: string = requireEnv('DEVICE_NAME');

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set via the ${name} env var`);
  }
  return value;
}
