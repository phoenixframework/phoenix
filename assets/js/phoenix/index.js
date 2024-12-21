/**
 * Phoenix Channels JavaScript Client (Updated)
 *
 * This module provides the tools to establish and manage channels and sockets
 * for communication between clients and servers. Updates include modern
 * JavaScript syntax, improved modularity, and refined documentation.
 * 
 * @module phoenix
 */

import Channel from "./channel.js";
import LongPoll from "./longpoll.js";
import Presence from "./presence.js";
import Serializer from "./serializer.js";
import Socket from "./socket.js";

/**
 * Exports for the Phoenix Channels module.
 * Provides streamlined imports for channel communication.
 */
export {
  Channel,
  LongPoll,
  Presence,
  Serializer,
  Socket,
};

/**
 * Example Usage:
 * ----------------
 * Import the Phoenix client module:
 * 
 * ```javascript
 * import { Socket, Channel } from "./phoenix";
 * 
 * // Create a new socket instance
 * const socket = new Socket("/socket", { params: { userToken: "123" } });
 * socket.connect();
 * 
 * // Join a channel
 * const channel = socket.channel("room:123", { token: "roomToken" });
 * 
 * channel.on("new_msg", (msg) => console.log("New message received:", msg));
 * 
 * channel.join()
 *   .receive("ok", ({ messages }) => console.log("Joined successfully:", messages))
 *   .receive("error", ({ reason }) => console.error("Failed to join:", reason));
 * ```
 */

/**
 * Changes in this version:
 * - ES module import/export syntax for better compatibility.
 * - Inline examples to guide developers through common use cases.
 * - Modern syntax (e.g., arrow functions, const/let).
 * - Consistent module naming with `.js` extensions for clarity.
 */
