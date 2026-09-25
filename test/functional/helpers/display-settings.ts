import assert from 'node:assert/strict';

/** Exercise the currentDisplayId setting against a live WDA session. */
export async function assertCurrentDisplayIdSetting(baseUrl: string, sessionId: string): Promise<void> {
  const screensResponse = await fetch(`${baseUrl}/wda/screens`);
  assert.equal(screensResponse.status, 200);
  const {value: screens} = (await screensResponse.json()) as {
    value: {displayId: number; isMain: boolean}[];
  };
  const main = screens.find((screen) => screen.isMain);
  assert.ok(main, 'expected a main display');
  const sessionUrl = `${baseUrl}/session/${sessionId}`;
  const setDisplay = async (value: unknown) =>
    await fetch(`${sessionUrl}/appium/settings`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({settings: {currentDisplayId: value}}),
    });
  const getDisplay = async () => {
    const response = await fetch(`${sessionUrl}/appium/settings`);
    assert.equal(response.status, 200);
    return ((await response.json()) as {value: {currentDisplayId: number}}).value.currentDisplayId;
  };
  const assertScreenshot = async () => {
    const response = await fetch(`${sessionUrl}/screenshot`);
    assert.equal(response.status, 200);
    const {value} = (await response.json()) as {value: string};
    assert.ok(Buffer.from(value, 'base64').length > 0, 'expected screenshot data');
  };

  assert.equal(await getDisplay(), main.displayId);
  assert.equal((await setDisplay(main.displayId)).status, 200);
  assert.equal(await getDisplay(), main.displayId);
  await assertScreenshot();

  const unknownId = Math.max(...screens.map((screen) => screen.displayId)) + 1;
  for (const value of [unknownId, 1.5, '1', true]) {
    const response = await setDisplay(value);
    assert.equal(response.status, 400, `expected invalid argument for ${JSON.stringify(value)}`);
    const {value: body} = (await response.json()) as {value: {error: string}};
    assert.equal(body.error, 'invalid argument');
  }
  assert.equal(await getDisplay(), main.displayId);

  assert.equal((await setDisplay(null)).status, 200);
  assert.equal(await getDisplay(), main.displayId);
  await assertScreenshot();
}
