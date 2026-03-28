import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger, Inject } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import * as jwt from 'jsonwebtoken';

interface AuthSocket extends Socket {
  userId?: number;
  userRole?: string;
}

@WebSocketGateway({
  cors: {
    origin: process.env.CORS_ORIGINS
      ? process.env.CORS_ORIGINS.split(',').map(s => s.trim())
      : ['https://aurixmusic.ru', 'https://www.aurixmusic.ru'],
  },
  namespace: '/support',
})
export class SupportGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly log = new Logger('SupportGateway');

  // Map ticketId → set of connected socket IDs
  private ticketRooms = new Map<string, Set<string>>();

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /** Authenticate on connect via token query param. */
  async handleConnection(client: AuthSocket) {
    try {
      const token = client.handshake.query.token as string;
      if (!token) {
        client.disconnect();
        return;
      }

      const secret = process.env.JWT_SECRET;
      if (!secret) { client.disconnect(); return; }
      const payload = jwt.verify(token, secret) as any;
      client.userId = payload.id;
      client.userRole = payload.role;
      this.log.log(`WS connected: user ${payload.id} (${payload.role})`);
    } catch (err) {
      this.log.warn(`WS auth failed: ${err}`);
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthSocket) {
    // Remove from all rooms
    for (const [ticketId, sockets] of this.ticketRooms) {
      sockets.delete(client.id);
      if (sockets.size === 0) this.ticketRooms.delete(ticketId);
    }
    this.log.log(`WS disconnected: ${client.userId}`);
  }

  /** Join a ticket chat room. */
  @SubscribeMessage('join_ticket')
  async handleJoinTicket(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() data: { ticket_id: string },
  ) {
    const ticketId = data.ticket_id;
    if (!ticketId) return;

    // Verify access: admin can join any, user only their own
    if (client.userRole !== 'admin') {
      const { rows } = await this.pool.query(
        'SELECT user_id FROM support_tickets WHERE id = $1',
        [ticketId],
      );
      if (!rows[0] || String(rows[0].user_id) !== String(client.userId)) {
        client.emit('error', { message: 'Access denied' });
        return;
      }
    }

    client.join(`ticket:${ticketId}`);
    if (!this.ticketRooms.has(ticketId)) {
      this.ticketRooms.set(ticketId, new Set());
    }
    this.ticketRooms.get(ticketId)!.add(client.id);

    this.log.log(`User ${client.userId} joined ticket:${ticketId}`);
    client.emit('joined', { ticket_id: ticketId });
  }

  /** Send a message in a ticket chat. */
  @SubscribeMessage('send_message')
  async handleSendMessage(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() data: { ticket_id: string; body: string },
  ) {
    if (!data.ticket_id || !data.body || !client.userId) return;

    // SECURITY: verify user has joined this ticket room
    const roomMembers = this.ticketRooms.get(data.ticket_id);
    if (!roomMembers || !roomMembers.has(client.id)) {
      client.emit('error', { message: 'Join the ticket room first' });
      return;
    }

    const senderRole = client.userRole === 'admin' ? 'admin' : 'user';

    // Persist to DB
    const { rows } = await this.pool.query(
      `INSERT INTO support_messages (ticket_id, sender_id, sender_role, body)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [data.ticket_id, client.userId, senderRole, data.body],
    );

    const message = rows[0];

    // Auto-update ticket status
    if (senderRole === 'admin') {
      await this.pool.query(
        `UPDATE support_tickets SET status = 'in_progress', updated_at = now()
         WHERE id = $1 AND status = 'open'`,
        [data.ticket_id],
      );
    }

    // Broadcast to everyone in the room
    this.server.to(`ticket:${data.ticket_id}`).emit('new_message', {
      ...message,
      sender_role: senderRole,
    });

    this.log.log(`Message in ticket:${data.ticket_id} from ${senderRole} (${client.userId})`);
  }

  /** Typing indicator. */
  @SubscribeMessage('typing')
  handleTyping(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() data: { ticket_id: string },
  ) {
    if (!data.ticket_id) return;
    client.to(`ticket:${data.ticket_id}`).emit('user_typing', {
      user_id: client.userId,
      role: client.userRole,
    });
  }

  /** Notify a ticket room about new events (called from services). */
  notifyTicket(ticketId: string, event: string, data: any) {
    this.server.to(`ticket:${ticketId}`).emit(event, data);
  }
}
