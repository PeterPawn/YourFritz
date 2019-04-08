<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:si="urn:yourfritz-de:signimage" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8" />
  <xsl:template match="/">
    <xsl:for-each select="si:database/si:devices">
      <xsl:apply-templates select="si:device" />
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="si:device"><xsl:apply-templates select="si:key" /></xsl:template>
  <xsl:template match="si:key">HWRevision="<xsl:value-of select="../@HWRevision" />" VersionMajor="<xsl:value-of select="../@VersionMajor" />" Model="<xsl:value-of select="../@name" />" Name="<xsl:value-of select="@original_name" />" Source="<xsl:value-of select="@source" />" Usage="<xsl:value-of select="@usage" />" Modulus="<xsl:value-of select="si:modulus" />" Exponent="<xsl:value-of select="si:exponent" />"<xsl:text>&#xa;</xsl:text></xsl:template>
</xsl:stylesheet> 
