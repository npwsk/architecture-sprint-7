### 1. Создаем сервисы с метками

```bash
# Создаем 4 сервиса с соответствующими метками
kubectl run front-end-app --image=nginx --labels=role=front-end --expose --port 80
kubectl run back-end-api-app --image=nginx --labels=role=back-end-api --expose --port 80
kubectl run admin-front-end-app --image=nginx --labels=role=admin-front-end --expose --port 80
kubectl run admin-back-end-api-app --image=nginx --labels=role=admin-back-end-api --expose --port 80
```

### 2. Создаем сетевые политики

Применяем политики:
```bash
kubectl apply -f network-policy.yml
```

### 3. Проверяем доступность сервисов

Проверим разрешенные соединения:
```bash
# Проверка front-end -> back-end-api
kubectl run test-frontend --rm -i -t --image=alpine --labels=role=front-end -- sh

> wget -qO- --timeout=2 http://back-end-api-app


# Проверка admin-front-end -> admin-back-end-api
kubectl run test-admin-frontend --rm -i -t --image=alpine --labels=role=admin-front-end -- sh 

> wget -qO- --timeout=2 http://admin-back-end-api-app

```

Проверим запрещенные соединения (должны завершиться ошибкой):
```bash
# Проверка front-end -> admin-back-end-api (должно быть запрещено)
kubectl run test-frontend-to-admin --rm -i -t --image=alpine --labels=role=front-end -- sh 

> wget -qO- --timeout=2 http://admin-back-end-api-app

# Проверка admin-front-end -> back-end-api (должно быть запрещено)
kubectl run test-admin-to-regular --rm -i -t --image=alpine --labels=role=admin-front-end -- sh 

> wget -qO- --timeout=2 http://back-end-api-app
```

### Объяснение политик:

1. `allow-frontend-to-backend`:
   - Разрешает трафик только от подов с меткой `role=front-end` к подам с меткой `role=back-end-api`
   - Только на порт 80 по TCP

2. `allow-admin-frontend-to-admin-backend`:
   - Разрешает трафик только от подов с меткой `role=admin-front-end` к подам с меткой `role=admin-back-end-api`
   - Только на порт 80 по TCP

3. `deny-all-other-traffic`:
   - Блокирует весь входящий трафик ко всем подам по умолчанию
   - Это гарантирует, что разрешен только явно указанный трафик в первых двух политиках

Таким образом, мы достигаем полной изоляции трафика между разными группами сервисов, разрешая взаимодействие только между соответствующими front-end и back-end компонентами.