import { Module, Global, Logger } from '@nestjs/common';
import { Pool } from 'pg';

const PG_POOL = 'PG_POOL';

const poolFactory = {
  provide: PG_POOL,
  useFactory: () => {
    const logger = new Logger('Database');
    const pool = new Pool({
      host: process.env.PG_HOST || 'localhost',
      port: Number(process.env.PG_PORT) || 5432,
      database: process.env.PG_DATABASE || 'aurixdb',
      user: process.env.PG_USER || 'aurix',
      password: process.env.PG_PASSWORD, // required via env validation
    });
    pool.on('error', (err) => {
      logger.error(`Unexpected pool error: ${err.message}`, err.stack);
    });
    logger.log('PostgreSQL pool initialized');
    return pool;
  },
};

@Global()
@Module({
  providers: [poolFactory],
  exports: [PG_POOL],
})
export class DatabaseModule {}

export { PG_POOL };
