const app = require('./server/app');
const { PORT, DB_PATH } = require('./server/config');
if (require.main === module) {
  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`SmartCenter: http://localhost:${server.address().port}`);
    console.log(`SQLite: ${DB_PATH}`);
  });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => process.exit(0)));
}
module.exports = app;
﻿
