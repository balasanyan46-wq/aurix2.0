## Summary

- 

## API Contract Checklist

- [ ] API contract changes include explicit `version` handling
- [ ] Backward compatibility is preserved (or migration plan documented)
- [ ] `POST /api/ai/chat` checked with one curl before deploy
- [ ] Flutter decoder compatibility verified (`chat_api_contract_test.dart`)
- [ ] No consumer still depends on response `reply` only
- [ ] `request_id` is available in logs/errors for debugging

## Test Plan

- [ ] Manual smoke in Flutter chat/studio screens
- [ ] Verify API endpoints respond correctly (`/api/ai/chat`, `/api/ai/cover`)

