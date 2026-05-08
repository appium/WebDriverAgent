declare module 'appium-ios-device' {
  export class Xctest {
    constructor(...args: any[]);
    start(): Promise<void>;
    stop(): void;
  }
}
