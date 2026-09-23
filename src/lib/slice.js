/**
 * slice.js — the player's slice of the network.
 *
 * The browser needs to know what is on and what to call it: every channel's
 * Transmission, and each film's title card. The programme notes, loglines and
 * archive links are already in the pages' HTML, so the scripts that tune in
 * do not carry them. network.json stays whole: it is the head-end
 * (/network.json), the Apple receiver's bundle, and the pages' build input.
 *
 * Each channel in the slice is still a valid Transmission (SPEC.md).
 */

/** The fields the web set, the guide and the on-air lines read. Nothing else. */
export function playerSlice(network) {
  return {
    channels: network.channels.map(({ transmission, id, number, name, epoch, blocks }) => ({
      transmission,
      id,
      number,
      name,
      epoch,
      blocks,
    })),
    films: Object.fromEntries(
      Object.entries(network.films).map(([slug, { title, year, director, durationSec }]) => [
        slug,
        { slug, title, year, director, durationSec },
      ])
    ),
  };
}
