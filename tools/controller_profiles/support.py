"""Keep implementation completion independent of physical hardware evidence."""


def theoretical_support(implementation, automatic, definitions, *, lifecycle_reviewed=False,
                        audio_routing_implemented=False, protocol_fixture_complete=False):
    unresolved = sum(sum(row["disposition"] not in {"mapped", "paired-low-byte"}
                         for row in definition.get("inputRecords", []) + definition.get("outputRecords", []))
                     for definition in definitions)
    if implementation == "protocol-needed":
        status = "protocol-needed"
    elif implementation == "adapter-needed":
        status = "adapter-needed"
    else:
        status = "core-implemented" if automatic or implementation == "linux-bridge" else "partial"
    criteria = {
        "protocolImplemented": implementation not in {"protocol-needed", "adapter-needed"},
        "documentedControlsComplete": bool(definitions) and unresolved == 0
            and all(item.get("sourceInputCount") == len(item.get("inputRecords", []))
                and item.get("sourceOutputCount") == len(item.get("outputRecords", []))
                and not item.get("unresolved") for item in definitions),
        "lifecycleReviewed": lifecycle_reviewed,
        "audioRoutingImplemented": audio_routing_implemented,
        "completeProtocolFixturePassed": protocol_fixture_complete,
    }
    complete = all(criteria.values())
    return {"status": "implemented" if complete else status, "complete": complete, "criteria": criteria,
            "untranslatedSourceRows": unresolved,
            "completionRequiresPhysicalTest": False,
            "remainingWork": [key for key, passed in criteria.items() if not passed]}


def theoretical_gate(models):
    physical = [model for model in models if model["isPhysicalModel"]]
    complete = sum(model["theoreticalSupport"]["complete"] for model in physical)
    return {"complete": bool(physical) and complete == len(physical), "implementedModels": complete,
            "targetModels": len(physical), "requiresPhysicalTestForEveryModel": False}
