defmodule MetricFlow.Agencies.AgencyClientAccessGrantTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Agencies.AgencyClientAccessGrant
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp new_grant do
    struct!(AgencyClientAccessGrant, [])
  end

  defp insert_grant!(attrs) do
    new_grant()
    |> AgencyClientAccessGrant.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      agency = account_fixture()
      client = account_fixture()
      attrs = valid_agency_client_access_grant_attrs(agency.id, client.id)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert changeset.valid?
    end

    test "casts agency_account_id correctly" do
      agency = account_fixture()
      client = account_fixture()
      attrs = valid_agency_client_access_grant_attrs(agency.id, client.id)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert get_change(changeset, :agency_account_id) == agency.id
    end

    test "casts client_account_id correctly" do
      agency = account_fixture()
      client = account_fixture()
      attrs = valid_agency_client_access_grant_attrs(agency.id, client.id)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert get_change(changeset, :client_account_id) == client.id
    end

    test "casts access_level correctly" do
      agency = account_fixture()
      client = account_fixture()
      attrs = valid_agency_client_access_grant_attrs(agency.id, client.id)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert get_change(changeset, :access_level) == :read_only
    end

    test "casts origination_status correctly" do
      agency = account_fixture()
      client = account_fixture()

      attrs =
        Map.put(
          valid_agency_client_access_grant_attrs(agency.id, client.id),
          :origination_status,
          :originator
        )

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert get_field(changeset, :origination_status) == :originator
    end

    test "validates agency_account_id is required" do
      agency = account_fixture()
      client = account_fixture()
      attrs = Map.delete(valid_agency_client_access_grant_attrs(agency.id, client.id), :agency_account_id)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      refute changeset.valid?
      assert %{agency_account_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates client_account_id is required" do
      agency = account_fixture()
      client = account_fixture()
      attrs = Map.delete(valid_agency_client_access_grant_attrs(agency.id, client.id), :client_account_id)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      refute changeset.valid?
      assert %{client_account_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates access_level is required" do
      agency = account_fixture()
      client = account_fixture()
      attrs = Map.delete(valid_agency_client_access_grant_attrs(agency.id, client.id), :access_level)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      refute changeset.valid?
      assert %{access_level: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows origination_status to be omitted (defaults to :invited)" do
      agency = account_fixture()
      client = account_fixture()

      attrs =
        agency.id
        |> valid_agency_client_access_grant_attrs(client.id)
        |> Map.delete(:origination_status)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert changeset.valid?
    end

    test "validates access_level is one of allowed enum values" do
      agency = account_fixture()
      client = account_fixture()

      for level <- [:read_only, :account_manager, :admin] do
        attrs =
          Map.put(valid_agency_client_access_grant_attrs(agency.id, client.id), :access_level, level)

        changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

        assert changeset.valid?, "expected #{level} to be a valid access_level"
      end
    end

    test "rejects invalid access_level values (e.g., :owner, :viewer)" do
      agency = account_fixture()
      client = account_fixture()

      attrs_owner =
        Map.put(valid_agency_client_access_grant_attrs(agency.id, client.id), :access_level, :owner)

      changeset_owner = AgencyClientAccessGrant.changeset(new_grant(), attrs_owner)

      refute changeset_owner.valid?
      assert %{access_level: [_]} = errors_on(changeset_owner)

      attrs_viewer =
        Map.put(valid_agency_client_access_grant_attrs(agency.id, client.id), :access_level, :viewer)

      changeset_viewer = AgencyClientAccessGrant.changeset(new_grant(), attrs_viewer)

      refute changeset_viewer.valid?
      assert %{access_level: [_]} = errors_on(changeset_viewer)
    end

    test "accepts :read_only as access_level" do
      agency = account_fixture()
      client = account_fixture()

      attrs =
        Map.put(valid_agency_client_access_grant_attrs(agency.id, client.id), :access_level, :read_only)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :access_level) == :read_only
    end

    test "accepts :account_manager as access_level" do
      agency = account_fixture()
      client = account_fixture()

      attrs =
        Map.put(
          valid_agency_client_access_grant_attrs(agency.id, client.id),
          :access_level,
          :account_manager
        )

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :access_level) == :account_manager
    end

    test "accepts :admin as access_level" do
      agency = account_fixture()
      client = account_fixture()

      attrs =
        Map.put(valid_agency_client_access_grant_attrs(agency.id, client.id), :access_level, :admin)

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :access_level) == :admin
    end

    test "validates origination_status is one of allowed enum values" do
      agency = account_fixture()
      client = account_fixture()

      for status <- [:invited, :originator] do
        attrs =
          Map.put(
            valid_agency_client_access_grant_attrs(agency.id, client.id),
            :origination_status,
            status
          )

        changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

        assert changeset.valid?, "expected #{status} to be a valid origination_status"
      end
    end

    test "rejects invalid origination_status values (e.g., :pending, :rejected)" do
      agency = account_fixture()
      client = account_fixture()

      attrs_pending =
        Map.put(
          valid_agency_client_access_grant_attrs(agency.id, client.id),
          :origination_status,
          :pending
        )

      changeset_pending = AgencyClientAccessGrant.changeset(new_grant(), attrs_pending)

      refute changeset_pending.valid?
      assert %{origination_status: [_]} = errors_on(changeset_pending)

      attrs_rejected =
        Map.put(
          valid_agency_client_access_grant_attrs(agency.id, client.id),
          :origination_status,
          :rejected
        )

      changeset_rejected = AgencyClientAccessGrant.changeset(new_grant(), attrs_rejected)

      refute changeset_rejected.valid?
      assert %{origination_status: [_]} = errors_on(changeset_rejected)
    end

    test "accepts :invited as origination_status" do
      agency = account_fixture()
      client = account_fixture()

      attrs =
        Map.put(
          valid_agency_client_access_grant_attrs(agency.id, client.id),
          :origination_status,
          :invited
        )

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert changeset.valid?
      assert get_field(changeset, :origination_status) == :invited
    end

    test "accepts :originator as origination_status" do
      agency = account_fixture()
      client = account_fixture()

      attrs =
        Map.put(
          valid_agency_client_access_grant_attrs(agency.id, client.id),
          :origination_status,
          :originator
        )

      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :origination_status) == :originator
    end

    test "validates agency_account association exists (assoc_constraint triggers on insert)" do
      client = account_fixture()
      attrs = valid_agency_client_access_grant_attrs(-1, client.id)

      {:error, changeset} =
        new_grant()
        |> AgencyClientAccessGrant.changeset(attrs)
        |> Repo.insert()

      assert %{agency_account: ["does not exist"]} = errors_on(changeset)
    end

    test "validates client_account association exists (assoc_constraint triggers on insert)" do
      agency = account_fixture()
      attrs = valid_agency_client_access_grant_attrs(agency.id, -1)

      {:error, changeset} =
        new_grant()
        |> AgencyClientAccessGrant.changeset(attrs)
        |> Repo.insert()

      assert %{client_account: ["does not exist"]} = errors_on(changeset)
    end

    test "enforces unique constraint on agency_account_id and client_account_id combination" do
      agency = account_fixture()
      client = account_fixture()
      attrs = valid_agency_client_access_grant_attrs(agency.id, client.id)

      _first = insert_grant!(attrs)

      {:error, changeset} =
        new_grant()
        |> AgencyClientAccessGrant.changeset(attrs)
        |> Repo.insert()

      assert %{agency_account_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same agency_account_id with different client_account_id values" do
      agency = account_fixture()
      client_one = account_fixture()
      client_two = account_fixture()

      attrs_one = valid_agency_client_access_grant_attrs(agency.id, client_one.id)
      _grant_one = insert_grant!(attrs_one)

      attrs_two = valid_agency_client_access_grant_attrs(agency.id, client_two.id)
      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs_two)

      assert changeset.valid?
    end

    test "allows same client_account_id with different agency_account_id values" do
      agency_one = account_fixture()
      agency_two = account_fixture()
      client = account_fixture()

      attrs_one = valid_agency_client_access_grant_attrs(agency_one.id, client.id)
      _grant_one = insert_grant!(attrs_one)

      attrs_two = valid_agency_client_access_grant_attrs(agency_two.id, client.id)
      changeset = AgencyClientAccessGrant.changeset(new_grant(), attrs_two)

      assert changeset.valid?
    end

    test "creates valid changeset for updating existing grant" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      update_attrs = %{access_level: :admin}
      changeset = AgencyClientAccessGrant.changeset(grant, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :access_level) == :admin
    end

    test "preserves existing fields when updating subset of attributes" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      update_attrs = %{access_level: :account_manager}
      changeset = AgencyClientAccessGrant.changeset(grant, update_attrs)

      assert changeset.data.agency_account_id == agency.id
      assert changeset.data.client_account_id == client.id
      assert changeset.data.origination_status == :invited
    end

    test "handles empty attributes map gracefully" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset = AgencyClientAccessGrant.changeset(grant, %{})

      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # originator_changeset/2
  # ---------------------------------------------------------------------------

  describe "originator_changeset/2" do
    test "creates valid changeset when origination_status is provided" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset = AgencyClientAccessGrant.originator_changeset(grant, %{origination_status: :originator})

      assert changeset.valid?
    end

    test "validates origination_status is required" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset =
        AgencyClientAccessGrant.originator_changeset(grant, %{origination_status: nil})

      refute changeset.valid?
      assert %{origination_status: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts :invited as origination_status" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset =
        AgencyClientAccessGrant.originator_changeset(grant, %{origination_status: :invited})

      assert changeset.valid?
      assert get_field(changeset, :origination_status) == :invited
    end

    test "accepts :originator as origination_status" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset =
        AgencyClientAccessGrant.originator_changeset(grant, %{origination_status: :originator})

      assert changeset.valid?
      assert get_change(changeset, :origination_status) == :originator
    end

    test "rejects invalid origination_status values (e.g., :pending)" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset =
        AgencyClientAccessGrant.originator_changeset(grant, %{origination_status: :pending})

      refute changeset.valid?
      assert %{origination_status: [_]} = errors_on(changeset)
    end

    test "does not cast or modify agency_account_id" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset =
        AgencyClientAccessGrant.originator_changeset(grant, %{
          origination_status: :originator,
          agency_account_id: -999
        })

      assert changeset.data.agency_account_id == agency.id
      assert get_change(changeset, :agency_account_id) == nil
    end

    test "does not cast or modify client_account_id" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset =
        AgencyClientAccessGrant.originator_changeset(grant, %{
          origination_status: :originator,
          client_account_id: -999
        })

      assert changeset.data.client_account_id == client.id
      assert get_change(changeset, :client_account_id) == nil
    end

    test "does not cast or modify access_level" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset =
        AgencyClientAccessGrant.originator_changeset(grant, %{
          origination_status: :originator,
          access_level: :admin
        })

      assert changeset.data.access_level == :read_only
      assert get_change(changeset, :access_level) == nil
    end

    test "handles empty attributes map by marking origination_status as missing" do
      agency = account_fixture()
      client = account_fixture()
      grant = insert_grant!(valid_agency_client_access_grant_attrs(agency.id, client.id))

      changeset =
        AgencyClientAccessGrant.originator_changeset(grant, %{origination_status: nil})

      refute changeset.valid?
      assert %{origination_status: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
