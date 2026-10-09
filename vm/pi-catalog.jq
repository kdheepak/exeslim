(length == 1 and (.[0] |
  .schemaVersion == 1
  and (.providers | type == "array" and length > 0)
  and all(.providers[];
    (.id | type == "string" and length > 0)
    and (.models | type == "array" and length > 0)
    and all(.models[];
      (.id | type == "string" and length > 0)
      and all(.cost.input, .cost.output, .cost.cacheRead, .cost.cacheWrite;
        type == "number" and . >= 0
      )
    )
  )
)) or error("Invalid pi pricing catalog")
