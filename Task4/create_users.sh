#!/bin/bash

# Параметры кластера
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
NAMESPACE="default" # Namespace для RBAC

# Список пользователей и их ролей
USERS=(
  "alice:auditor"
  "bob:developer"
)

# Функция создания пользователя
create_user() {
  local USERNAME=$1
  local ROLE=$2

  echo -e "Создание пользователя $USERNAME с ролью '$ROLE'"

  # Шаг 1: Генерация ключа и CSR
  echo "Генерация ключа и CSR..."
  openssl genrsa -out "$USERNAME.key" 2048
  openssl req -new -key "$USERNAME.key" -out "$USERNAME.csr" -subj "/CN=$USERNAME"

  # Шаг 2: Отправка CSR в кластер
  echo "Создание Kubernetes CSR..."
  cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $USERNAME-csr
spec:
  request: $(cat "$USERNAME.csr" | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

  # Шаг 3: Одобрение CSR
  echo "Одобрение CSR..."
  kubectl certificate approve "$USERNAME-csr"

  # Шаг 4: Получение сертификата
  echo "Сохранение сертификата..."
  kubectl get csr "$USERNAME-csr" -o jsonpath='{.status.certificate}' | base64 -d > "$USERNAME.crt"

  # Шаг 5: Добавление в kubeconfig
  echo "Настройка kubeconfig..."
  kubectl config set-credentials "$USERNAME" \
    --client-key="$USERNAME.key" \
    --client-certificate="$USERNAME.crt" \
    --embed-certs=true

  kubectl config set-context "$USERNAME-context" \
    --cluster="$CLUSTER_NAME" \
    --user="$USERNAME"

  # Шаг 6: Привязка роли
  if [ "$ROLE" == "auditor" ]; then
    echo "Создание ClusterRoleBinding для auditor..."
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $USERNAME-$ROLE-binding
subjects:
- kind: User
  name: $USERNAME
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: $ROLE
  apiGroup: rbac.authorization.k8s.io
EOF
  else
    echo "Создание RoleBinding для developer..."
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $USERNAME-$ROLE-binding
  namespace: default
subjects:
- kind: User
  name: $USERNAME
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: $ROLE
  apiGroup: rbac.authorization.k8s.io
EOF
  fi

  # Проверка доступа
  echo "Проверка доступа для $USERNAME"
  kubectl config use-context "$USERNAME-context"

  if [ "$ROLE" == "auditor" ]; then
    OUTPUT=$(kubectl get nodes 2>&1)
    if [[ "$OUTPUT" == *"NAME"* ]] || [[ "$OUTPUT" == *"No resources found"* ]]; then
      echo "Успешно!"
    else
      echo "Ошибка доступа: $OUTPUT"
    fi
  else
    OUTPUT=$(kubectl get pods -n default 2>&1)
    if [[ "$OUTPUT" == *"NAME"* ]] || [[ "$OUTPUT" == *"No resources found"* ]]; then
      echo "Успешно!"
    else
      echo "Ошибка доступа: $OUTPUT"
    fi
  fi

  # Возврат к исходному контексту
  kubectl config use-context "$CLUSTER_NAME"
}

kubectl config use-context "$CLUSTER_NAME"

# Создание пользователей
for USER_SPEC in "${USERS[@]}"; do
  IFS=':' read -r USERNAME ROLE <<< "$USER_SPEC"

  # Удаление пользователя, если он есть
  rm -f $USERNAME.key $USERNAME.csr $USERNAME.crt
  kubectl config delete-user $USERNAME
  kubectl config delete-context $USERNAME-context
  kubectl delete csr $USERNAME-csr

  create_user "$USERNAME" "$ROLE"
done

echo "Список пользователей и их контекстов:"
kubectl config get-contexts
