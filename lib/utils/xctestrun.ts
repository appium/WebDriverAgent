import {fs, plist, util} from '@appium/support';
import path from 'node:path';
import {arch} from 'node:os';
import {log} from '../logger';
import type {DeviceInfo} from '../types';
import {isTvOS} from './platform';

/**
 * Arguments for setting xctestrun file
 */
export interface XctestrunFileArgs {
  deviceInfo: DeviceInfo;
  sdkVersion: string;
  bootstrapPath: string;
  wdaRemotePort: number | string;
  wdaBindingIP?: string;
  maxHttpRequestBodySize?: number | string;
}

/**
 * Creates xctestrun file per device & platform version.
 * We expect to have WebDriverAgentRunner_iphoneos${sdkVersion|platformVersion}-arm64.xctestrun for real device
 * and WebDriverAgentRunner_iphonesimulator${sdkVersion|platformVersion}-${x86_64|arm64}.xctestrun for simulator located @bootstrapPath
 * Newer Xcode (Xcode 10.0 at least) generates xctestrun file following sdkVersion.
 * e.g. Xcode which has iOS SDK Version 12.2 on an intel Mac host machine generates WebDriverAgentRunner_iphonesimulator.2-x86_64.xctestrun
 *      even if the cap has platform version 11.4
 *
 * @param args
 * @return returns xctestrunFilePath for given device
 * @throws if WebDriverAgentRunner_iphoneos${sdkVersion|platformVersion}-arm64.xctestrun for real device
 * or WebDriverAgentRunner_iphonesimulator${sdkVersion|platformVersion}-x86_64.xctestrun for simulator is not found @bootstrapPath,
 * then it will throw a file not found exception
 */
export async function setXctestrunFile(args: XctestrunFileArgs): Promise<string> {
  const {
    deviceInfo,
    sdkVersion,
    bootstrapPath,
    wdaRemotePort,
    wdaBindingIP,
    maxHttpRequestBodySize,
  } = args;
  const xctestrunFilePath = await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath);
  const xctestRunContent = await plist.parsePlistFile(xctestrunFilePath);
  const updateWDAPort = getAdditionalRunContent(
    deviceInfo.platformName,
    wdaRemotePort,
    wdaBindingIP,
    maxHttpRequestBodySize,
  );
  const newXctestRunContent = mergeObjects(xctestRunContent, updateWDAPort);
  await plist.updatePlistFile(xctestrunFilePath, newXctestRunContent, true);

  return xctestrunFilePath;
}

/**
 * Return the WDA object which appends existing xctest runner content
 * @param platformName - The name of the platform
 * @param wdaRemotePort - The remote port number
 * @param wdaBindingIP - The IP address to bind to. If not given, it binds to all interfaces.
 * @param maxHttpRequestBodySize - The maximum HTTP request body size in bytes.
 * @return returns a runner object which has USE_PORT and optionally USE_IP
 */
export function getAdditionalRunContent(
  platformName: string,
  wdaRemotePort: number | string,
  wdaBindingIP?: string,
  maxHttpRequestBodySize?: number | string,
): Record<string, any> {
  const runner = `WebDriverAgentRunner${isTvOS(platformName) ? '_tvOS' : ''}`;
  return {
    [runner]: {
      EnvironmentVariables: {
        // USE_PORT must be 'string'
        USE_PORT: `${wdaRemotePort}`,
        ...(wdaBindingIP ? {USE_IP: wdaBindingIP} : {}),
        ...(maxHttpRequestBodySize
          ? {MAX_HTTP_REQUEST_BODY_SIZE: `${maxHttpRequestBodySize}`}
          : {}),
      },
    },
  };
}

/**
 * Return the path of xctestrun if it exists
 * @param deviceInfo
 * @param sdkVersion - The Xcode SDK version of OS.
 * @param bootstrapPath - The folder path containing xctestrun file.
 */
export async function getXctestrunFilePath(
  deviceInfo: DeviceInfo,
  sdkVersion: string,
  bootstrapPath: string,
): Promise<string> {
  // First try the SDK path, for Xcode 10 (at least)
  const sdkBased: [string, string] = [
    path.resolve(bootstrapPath, `${deviceInfo.udid}_${sdkVersion}.xctestrun`),
    sdkVersion,
  ];
  // Next try Platform path, for earlier Xcode versions
  const platformBased: [string, string] = [
    path.resolve(bootstrapPath, `${deviceInfo.udid}_${deviceInfo.platformVersion}.xctestrun`),
    deviceInfo.platformVersion,
  ];

  for (const [filePath, version] of [sdkBased, platformBased]) {
    if (await fs.exists(filePath)) {
      log.info(`Using '${filePath}' as xctestrun file`);
      return filePath;
    }
    const originalXctestrunFile = path.resolve(
      bootstrapPath,
      getXctestrunFileName(deviceInfo, version),
    );
    if (await fs.exists(originalXctestrunFile)) {
      // If this is first time run for given device, then first generate xctestrun file for device.
      // We need to have a xctestrun file **per device** because we cannot have same wda port for all devices.
      await fs.copyFile(originalXctestrunFile, filePath);
      log.info(`Using '${filePath}' as xctestrun file copied by '${originalXctestrunFile}'`);
      return filePath;
    }
  }

  throw new Error(
    `If you are using 'useXctestrunFile' capability then you ` +
      `need to have a xctestrun file (expected: ` +
      `'${path.resolve(bootstrapPath, getXctestrunFileName(deviceInfo, sdkVersion))}')`,
  );
}

/**
 * Return the name of xctestrun file
 * @param deviceInfo
 * @param version - The Xcode SDK version of OS.
 * @return returns xctestrunFilePath for given device
 */
export function getXctestrunFileName(deviceInfo: DeviceInfo, version: string): string {
  const archSuffix = deviceInfo.isRealDevice
    ? `os${version}-arm64`
    : `simulator${version}-${arch() === 'arm64' ? 'arm64' : 'x86_64'}`;
  return `WebDriverAgentRunner_${isTvOS(deviceInfo.platformName) ? 'tvOS_appletv' : 'iphone'}${archSuffix}.xctestrun`;
}

function mergeObjects<T extends Record<string, any>, U extends Record<string, any>>(
  target: T,
  source: U,
): T & U {
  const output: Record<string, any> = {...target};
  for (const [key, sourceValue] of Object.entries(source)) {
    const targetValue = output[key];
    if (util.isPlainObject(targetValue) && util.isPlainObject(sourceValue)) {
      output[key] = mergeObjects(targetValue, sourceValue);
      continue;
    }
    output[key] = sourceValue;
  }
  return output as T & U;
}
