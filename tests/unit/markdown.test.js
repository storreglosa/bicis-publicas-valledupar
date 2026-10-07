import { describe, expect, it } from 'vitest'
import { markdownSeguro } from '../../src/lib/markdown.js'

describe('markdownSeguro', () => {
  it('convierte títulos, listas, párrafos y negrita', () => {
    const html = markdownSeguro('# Política\n\nTexto **importante**\nsigue.\n\n- uno\n- dos')
    expect(html).toBe('<h2>Política</h2>\n<p>Texto <strong>importante</strong> sigue.</p>\n<ul><li>uno</li><li>dos</li></ul>')
  })

  it('escapa cualquier HTML: no hay inyección', () => {
    const html = markdownSeguro('<img src=x onerror=alert(1)> **<script>**')
    expect(html).not.toContain('<img')
    expect(html).not.toContain('<script>')
    expect(html).toContain('&lt;img src=x onerror=alert(1)&gt;')
  })
})
