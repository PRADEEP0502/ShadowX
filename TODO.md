# TODO

## Frontend: Connect Register/Login to FastAPI backend
- [ ] Update `frontend/pubspec.yaml` to add `http: ^1.2.1`
- [ ] Create `frontend/lib/core/constants/api_constants.dart` with `baseUrl`
- [ ] Create `frontend/lib/services/api_service.dart` implementing `register()` and `login()`
- [ ] Update `frontend/lib/screens/register_screen.dart` button to call `ApiService.register()` and handle success/failure
- [ ] Update `frontend/lib/screens/login_screen.dart` button to call `ApiService.login()` and handle success/failure
- [ ] Run `cd frontend && flutter pub get`
- [ ] Run `cd frontend && flutter analyze`
- [ ] Manual test: register (Mongo save) and login (navigate to home)

## (If needed later)
- [ ] Fix CORS for Flutter web by adding FastAPI CORS middleware



