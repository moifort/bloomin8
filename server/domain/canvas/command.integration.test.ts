import { afterEach, beforeEach, describe, expect, spyOn, test } from 'bun:test'
import { CanvasCommand } from '~/domain/canvas/command'
import { CanvasUrl, ServerUrl } from '~/domain/config/primitives'
import { resetMemoryStorage } from '~/testing/memory-storage'

const serverUrl = ServerUrl('http://canvas.local:3000')
const canvasUrl = CanvasUrl('http://canvas.test')
const nextPullAt = new Date('2026-11-20T14:00:00Z')

beforeEach(() => {
  resetMemoryStorage()
  spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{"upstream_on":true}'))
})

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore: () => void }).mockRestore()
})

describe('CanvasCommand.repointUpstreamIfOutdated', () => {
  test('repoints a device that pulled through an old address, keeping its next pull', async () => {
    await CanvasCommand.recordPulledVia('192.168.1.199:3000')

    const outcome = await CanvasCommand.repointUpstreamIfOutdated(canvasUrl, serverUrl, nextPullAt)

    expect(outcome).toEqual({ repointedFrom: '192.168.1.199:3000', to: serverUrl })
    const [url, init] = (
      globalThis.fetch as unknown as { mock: { calls: [string, RequestInit][] } }
    ).mock.calls[0]
    expect(url).toBe('http://canvas.test/upstream/pull_settings')
    expect(JSON.parse(init.body as string)).toMatchObject({
      upstream_url: 'http://canvas.local:3000',
      cron_time: '2026-11-20T14:00:00Z',
    })
  })

  test('repoints only once', async () => {
    await CanvasCommand.recordPulledVia('192.168.1.199:3000')
    await CanvasCommand.repointUpstreamIfOutdated(canvasUrl, serverUrl, nextPullAt)

    expect(await CanvasCommand.repointUpstreamIfOutdated(canvasUrl, serverUrl, nextPullAt)).toBe(
      'up-to-date',
    )
    expect(globalThis.fetch).toHaveBeenCalledTimes(1)
  })

  test('leaves a device already on the server URL alone', async () => {
    await CanvasCommand.recordPulledVia('canvas.local:3000')

    expect(await CanvasCommand.repointUpstreamIfOutdated(canvasUrl, serverUrl, nextPullAt)).toBe(
      'up-to-date',
    )
    expect(globalThis.fetch).not.toHaveBeenCalled()
  })

  test('keeps the outdated address when the device does not answer, to retry next pull', async () => {
    ;(globalThis.fetch as unknown as { mockRejectedValue: (e: Error) => void }).mockRejectedValue(
      new Error('asleep'),
    )
    await CanvasCommand.recordPulledVia('192.168.1.199:3000')

    await expect(
      CanvasCommand.repointUpstreamIfOutdated(canvasUrl, serverUrl, nextPullAt),
    ).rejects.toThrow('asleep')
  })
})
