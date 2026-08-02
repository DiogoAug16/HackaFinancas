FROM nodered/node-red:4.1.10

COPY --chown=node-red:node-red package.json /data/
RUN cd /data && npm install --omit=dev --no-audit --no-fund
COPY --chown=node-red:node-red settings.js flows.json /data/
