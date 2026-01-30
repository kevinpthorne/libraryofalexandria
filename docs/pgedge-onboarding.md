
# pgEdge federated app onboarding

Phase 1: The "Uniform" Foundation (Crossplane)

Apply these resources to ALL nodes (A-rw, B-rw, A-r).

    Crossplane: Create Schema (e.g., my_app).

    Crossplane: Create Extension (spock).

    Job: Run spock.node_create on all nodes.

Phase 2: Cluster A Launch (The "Prime" Mover)

    Job: Enable Subscription Node A-r --> Node A-rw (Replica follows A).

    App A: Deploy & Run Migrations.

        Result: Tables created on A-rw.

        Result: Spock immediately copies tables to A-r.

Phase 3: Cluster B Launch (The "Joiner")

    Job: Enable Subscription Node B-rw --> Node A-rw.

        Result: This is the critical sync. B-rw pulls the table definitions from A-rw.

    Job: Enable Subscription Node A-rw --> Node B-rw.

        Result: Bi-directional link established.

    Job: Enable Subscription Node A-r --> Node B-rw (Optional).

        Result: Replica now pulls from both active nodes (High Availability for the replica).

    App B: Deploy.

        Result: Connects to B-rw. Sees tables exist. Skips migrations. Ready for traffic.