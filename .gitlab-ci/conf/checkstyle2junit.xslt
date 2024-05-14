<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output encoding="UTF-8" method="xml"></xsl:output>

  <xsl:template match="/">
    <testsuite>
      <xsl:attribute name="tests">
        <xsl:value-of select="count(.//file)" />
      </xsl:attribute>
      <xsl:attribute name="failures">
        <xsl:value-of select="count(.//error)" />
      </xsl:attribute>
      <xsl:for-each select="//checkstyle">
        <xsl:apply-templates />
      </xsl:for-each>
    </testsuite>
  </xsl:template>

  <xsl:template match="file">
    <testcase>
      <xsl:attribute name="file">
        <xsl:value-of select="@name" />
      </xsl:attribute>
      <xsl:attribute name="classname">
        <xsl:choose>
          <xsl:when test="error">
            <xsl:value-of select="substring-after(error[1]/@source, 'eslint.rules.')" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>eslint.passed</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="name">
        <xsl:choose>
          <xsl:when test="error">
            <xsl:value-of select="error[1]/@line" />
            <xsl:text>:</xsl:text>
            <xsl:value-of select="error[1]/@column" />
            <xsl:text> = </xsl:text>
            <xsl:value-of select="error[1]/@message" />
          </xsl:when>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates select="node()" />
    </testcase>
  </xsl:template>

  <xsl:template match="error">
    <failure>
      <xsl:attribute name="type">
        <xsl:value-of select="@severity" />
      </xsl:attribute>
      <xsl:value-of select="@line" />
      <xsl:text>:</xsl:text>
      <xsl:value-of select="@message" />
      <xsl:text>&amp; </xsl:text>
      <xsl:value-of select="@source" />
    </failure>
  </xsl:template>
</xsl:stylesheet>